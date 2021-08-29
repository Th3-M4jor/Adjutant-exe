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
      for n <- 1..System.schedulers_online() do
        Supervisor.child_spec(
          {BnBBot.Consumer, []},
          id: {:bnb_bot, :consumer, n},
          restart: :temporary
        )
      end

    # Logger.debug(inspect(children))

    ncp =
      Supervisor.child_spec(
        {BnBBot.Library.NCPTable, []},
        id: {:bnb_bot, :ncp_table},
        restart: :transient
      )

    chips =
      Supervisor.child_spec(
        {BnBBot.Library.BattlechipTable, []},
        id: {:bnb_bot, :chip_table},
        restart: :transient
      )

    viruses =
      Supervisor.child_spec(
        {BnBBot.Library.VirusTable, []},
        id: {:bnb_bot, :virus_table},
        restart: :transient
      )

    children = [ncp | children]
    children = [chips | children]
    children = [viruses | children]
    Logger.debug(inspect(children, pretty: true))

    res = Supervisor.init(children, strategy: :one_for_one)
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
    Logger.debug("Bot ready")

    # prefix = Application.fetch_env!(:elixir_bot, :prefix)

    Api.update_status(:online, "Now with Slash Commands")

    {dm_msg, override} =
      case :ets.lookup(:bnb_bot_data, :first_ready) do
        [first_ready: false] ->
          Logger.warn("Ready re-emitted #{inspect(ready_data, pretty: true)}")
          {"ready re-emitted", true}

        _ ->
          :ets.insert(:bnb_bot_data, first_ready: false)

          # ncp_task = Task.async(fn -> BnBBot.Library.NCP.load_ncps() end)
          # chips_task = Task.async(fn -> BnBBot.Library.Battlechip.load_chips() end)
          chip_ct = BnBBot.Library.Battlechip.get_chip_ct()
          ncp_ct = BnBBot.Library.NCP.get_ncp_ct()
          virus_ct = BnBBot.Library.Virus.get_virus_ct()
          # [ok: ncp_ct, ok: chip_ct] = Task.await_many([ncp_task, chips_task], :infinity)
          Logger.debug("Ready #{inspect(ready_data, pretty: true)}")

          {"Bot Ready\n#{chip_ct} chips loaded\n#{virus_ct} viruses loaded\n#{ncp_ct} ncps loaded",
           false}
      end

    BnBBot.Util.dm_owner(dm_msg, override)
  end

  def handle_event({:RESUMED, resume_data, _ws_state}) do
    Logger.debug("Bot resumed #{inspect(resume_data, pretty: true)}")
    BnBBot.Util.dm_owner("Bot Resumed")
  end

  # button clicks
  def handle_event({:INTERACTION_CREATE, %Nostrum.Struct.Interaction{} = inter, _ws_state})
      when inter.type == 3 do
    Logger.debug("Got an interaction button click on #{inter.message.id}")
    Logger.debug("#{inspect(inter, pretty: true)}")

    case String.split(inter.data.custom_id, "_", parts: 3) do
      # Ensure that the custom_id starts with a number before trying to parse
      [<<head, _rest::binary>> = id, _, _] when head in ?1..?9 ->
        id = String.to_integer(id)
        BnBBot.ButtonAwait.resp_to_btn(inter, id)

      ["cr", chip_name] ->
        {:found, chip} = BnBBot.Library.Battlechip.get_chip(chip_name)
        Api.create_interaction_response(inter,
          %{
            type: 4,
            data: %{
              content: "#{chip}"
            }
          }
        )

      ["nr", ncp_name] ->
        {:found, ncp} = BnBBot.Library.NCP.get_ncp(ncp_name)
        Api.create_interaction_response(inter,
          %{
            type: 4,
            data: %{
              content: "#{ncp}"
            }
          }
        )

      ["vr", virus_name] ->
        {:found, virus} = BnBBot.Library.Virus.get_virus(virus_name)
        Api.create_interaction_response(inter,
          %{
            type: 4,
            data: %{
              content: "#{virus}"
            }
          }
        )

      _ ->
        BnBBot.ButtonAwait.resp_to_btn(inter, inter.message.id)
    end
  end

  # slash commands and context menu
  def handle_event({:INTERACTION_CREATE, %Nostrum.Struct.Interaction{} = inter, _ws_state})
      when inter.type == 2 do
    Logger.debug("Got an interaction command")
    Logger.debug("#{inspect(inter, pretty: true)}")

    try do
      BnBBot.SlashCommands.handle_command(inter)
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))

        {:ok} =
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
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(_event) do
    # Logger.debug("Got event #{inspect(event, pretty: true)}")
    :noop
  end
end
