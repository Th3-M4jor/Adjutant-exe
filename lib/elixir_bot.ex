defmodule BnBBot.Supervisor do
  require Logger
  use Supervisor
  # use Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
    # Registry.start_link(keys: :unique, name: :REACTION_COLLECTOR)
    Registry.start_link(keys: :unique, name: :BUTTON_COLLECTOR)
  end

  @impl true
  def init(_init_arg) do
    Logger.debug("Starting Supervisor")

    :ets.new(:bnb_bot_data, [:set, :public, :named_table, read_concurrency: true])
    # recommended to spawn one per scheduler (default is number of cores)
    children =
      for n <- 1..System.schedulers_online(),
          do: Supervisor.child_spec({BnBBot.Consumer, []}, id: {:bnb_bot, :consumer, n})

    res = Supervisor.init(children, strategy: :one_for_one, restart: :temporary)
    Logger.debug("Supervisor started")
    # :ignore
    res
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
    :noop
  end

  def handle_event({:MESSAGE_CREATE, %Nostrum.Struct.Message{} = msg, _ws_state}) do
    if is_nil(msg.guild_id) do
      Task.start(fn -> BnBBot.DmLogger.log_dm(msg) end)
    end

    try do
      BnBBot.Commands.cmd_check(msg)
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        Api.create_message(msg.channel_id, "An error has occurred, inform Major")
    end
  end

  def handle_event({:READY, ready_data, _ws_state}) do
    # Logger.debug("Bot ready")

    # prefix = Application.fetch_env!(:elixir_bot, :prefix)

    Api.update_status(:online, "I have slash commands now")

    {dm_msg, override} =
      case :ets.lookup(:bnb_bot_data, :first_ready) do
        [first_ready: false] ->
          Logger.warn("Ready re-emitted #{inspect(ready_data, pretty: true)}")
          {"ready re-emitted", true}

        _ ->
          :ets.insert(:bnb_bot_data, first_ready: false)

          ncp_task = Task.async(fn -> BnBBot.Library.NCP.load_ncps() end)
          chips_task = Task.async(fn -> BnBBot.Library.Battlechip.load_chips() end)
          [ok: ncp_ct, ok: chip_ct] = Task.await_many([ncp_task, chips_task], :infinity)
          Logger.debug("Ready #{inspect(ready_data, pretty: true)}")
          {"Bot Ready\n#{chip_ct} chips loaded\n#{ncp_ct} ncps loaded", false}
      end

    BnBBot.Util.dm_owner(dm_msg, override)
  end

  def handle_event({:RESUMED, resume_data, _ws_state}) do
    Logger.debug("Bot resumed #{inspect(resume_data, pretty: true)}")
    BnBBot.Util.dm_owner("Bot Resumed")
  end

  def handle_event({:INTERACTION_CREATE, %Nostrum.Struct.Interaction{} = inter, _ws_state})
      when inter.type == 3 do
    Logger.debug("Got an interaction button click on #{inter.message.id}")
    Logger.debug("#{inspect(inter, pretty: true)}")

    to_lookup =
      case String.split(inter.data.custom_id, "_", parts: 3) do
        # Ensure that the custom_id starts with a number before trying to parse
        [<<head, _rest::binary>> = id, _, _] when head in ?1..?9 ->
          String.to_integer(id)

        _ ->
          inter.message.id
      end

    case Registry.lookup(:BUTTON_COLLECTOR, to_lookup) do
      [{pid, user_id}]
      when is_nil(user_id)
      when inter.user.id == user_id
      when inter.member.user.id == user_id ->
        send(pid, {:btn_click, inter})

      _ ->
        Logger.debug("Interaction wasn't registered, or wasn't for said user")

        Api.create_interaction_response(
          inter,
          %{
            type: 4,
            data: %{
              content:
                "You're not the one that I created this for, or I'm no longer listening for events on it, sorry",
              # 64 is the flag for ephemeral messages
              flags: 64
            }
          }
        )
    end
  end

  def handle_event({:INTERACTION_CREATE, %Nostrum.Struct.Interaction{} = inter, _ws_state})
      when inter.type == 2 do
    Logger.debug("Got an interaction command")
    Logger.debug("#{inspect(inter, pretty: true)}")

    try do
      BnBBot.SlashCommands.handle_command(inter)
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))

        Api.create_interaction_response(
          inter,
          %{
            type: 4,
            data: %{
              content: "An error has occurred, inform Major",
              flags: 64
            }
          }
        )
    end

    # Api.create_interaction_response(
    #  inter,
    #  %{
    #    type: 4,
    #    data: %{
    #      content: "Pong!"
    #    }
    #  }
    # )
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(_event) do
    # Logger.debug("Got event #{inspect(event, pretty: true)}")
    :noop
  end
end
