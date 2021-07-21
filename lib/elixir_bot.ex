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
    children = [BnBBot.Consumer]

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

    # Task.start(fn ->
    BnBBot.Commands.cmd_check(msg)
    # end)

    # case msg.content do
    #   "!sleep" ->
    #     Api.create_message(msg.channel_id, "Going to sleep...")
    #     # This won't stop other events from being handled.
    #     Process.sleep(3000)

    #   "!ping" ->
    #     Api.create_message(msg.channel_id, "pong!")
    #     Logger.info("recieved a ping")
    #   "!raise" ->
    #     # This won't crash the entire Consumer.
    #     raise "No problems here!"

    #   _ ->
    #     :ignore
    # end
  end

  def handle_event({:READY, _ready_data, _ws_state}) do
    Logger.info("Bot ready")
    ready_channel = Application.fetch_env!(:elixir_bot, :ready_channel)
    Api.create_message(ready_channel, "Bot ready")
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
