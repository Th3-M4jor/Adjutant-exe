defmodule BnBBot.Supervisor do
  require Logger
  use Supervisor
  # use Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
    Registry.start_link(keys: :unique, name: :REACTION_COLLECTOR)
  end

  @impl true
  def init(_init_arg) do
    Logger.debug("Starting Supervisor")

    :ets.new(:bnb_bot_data, [:set, :public, :named_table, read_concurrency: true])
    # recommended to spawn one per scheduler (default is number of cores)
    children =
      for n <- 1..System.schedulers_online(),
          do: Supervisor.child_spec({BnBBot.Consumer, []}, id: {:bnb_bot, :consumer, n})

    Supervisor.init(children, strategy: :one_for_one, restart: :temporary)
  end
end

defmodule BnBBot.Consumer do
  require Logger
  use Nostrum.Consumer

  alias Nostrum.Api

  def start_link do
    Logger.debug("starting Consumer Link")
    # don't restart crashed commands
    Consumer.start_link(__MODULE__, max_restarts: 0)
  end

  def handle_event({:MESSAGE_CREATE, %Nostrum.Struct.Message{} = msg, _ws_state})
      when msg.author.bot do
    Logger.debug("Recieved a bot message")
  end

  def handle_event({:MESSAGE_CREATE, %Nostrum.Struct.Message{} = msg, _ws_state}) do
    Logger.debug("Recieved a non-bot message")

    try do
      BnBBot.Commands.cmd_check(msg)
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        Api.create_message(msg.channel_id, "An error has occurred, inform Major")
    end
  end

  def handle_event({:READY, ready_data, _ws_state}) do
    Logger.debug("Bot ready")

    {dm_msg, override} =
      case :ets.lookup(:bnb_bot_data, :first_ready) do
        [first_ready: false] ->
          Logger.warn("Ready re-emitted #{inspect(ready_data)}")
          {"ready re-emitted", true}

        _ ->
          :ets.insert(:bnb_bot_data, first_ready: false)
          BnBBot.Library.NCP.load_ncps()
          {"Bot Ready", false}
      end

    BnBBot.Util.dm_owner(dm_msg, override)
  end

  def handle_event({:RESUMED, _resume_data, _ws_state}) do
    Logger.debug("Bot resumed")
    BnBBot.Util.dm_owner("Bot Resumed")
  end

  def handle_event({:MESSAGE_REACTION_ADD, reaction, _was_state}) do
    Logger.debug("Got a reaction")
    # [{pid, user_id}] = Registry.lookup(:REACTION_COLLECTOR, reaction.message_id)
    case Registry.lookup(:REACTION_COLLECTOR, reaction.message_id) do
      [{pid, user_id}] when is_nil(user_id) or reaction.user_id == user_id ->
        send(pid, {:reaction, reaction})

      _ ->
        nil
    end
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(_event) do
    :noop
  end
end
