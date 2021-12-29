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

  @primary_guild_id :elixir_bot |> Application.compile_env!(:primary_guild_id)
  @primary_guild_channel_id :elixir_bot |> Application.compile_env!(:primary_guild_channel_id)
  @primary_guild_role_channel_id :elixir_bot
                                 |> Application.compile_env!(:primary_guild_role_channel_id)
  @log_channel_id :elixir_bot |> Application.compile_env!(:dm_log_id)
  def start_link do
    Logger.debug("starting Consumer Link")
    # don't retry on events that raise an error
    Consumer.start_link(__MODULE__, max_restarts: 0)
  end

  # ignore bots
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

  def handle_event(
        {:GUILD_MEMBER_ADD, {guild_id, %Nostrum.Struct.Guild.Member{} = member}, _ws_state}
      ) do
    if guild_id == @primary_guild_id do
      text =
        "Welcome to the Busters & Battlechips Discord <@#{member.user.id}>. Assign yourself roles in <##{@primary_guild_role_channel_id}>"

      Api.create_message!(@primary_guild_channel_id, text)
    end
  end

  def handle_event(
        {:GUILD_MEMBER_REMOVE, {guild_id, %Nostrum.Struct.Guild.Member{} = member}, _ws_state}
      ) do
    text = "#{member.user.username} has left #{guild_id}"
    Api.create_message!(@log_channel_id, text)
  end

  def handle_event({:READY, ready_data, _ws_state}) do
    Logger.debug("Bot ready")

    Api.update_status(:online, "Now with Slash Commands")

    {dm_msg, override} =
      case :ets.lookup(:bnb_bot_data, :first_ready) do
        [first_ready: false] ->
          Logger.warn(["Ready re-emitted\n", inspect(ready_data, pretty: true)])
          {"ready re-emitted", true}

        _ ->
          :ets.insert(:bnb_bot_data, first_ready: false)

          # ncp_task = Task.async(fn -> BnBBot.Library.NCP.load_ncps() end)
          # chips_task = Task.async(fn -> BnBBot.Library.Battlechip.load_chips() end)
          chip_ct = BnBBot.Library.Battlechip.get_chip_ct()
          ncp_ct = BnBBot.Library.NCP.get_ncp_ct()
          virus_ct = BnBBot.Library.Virus.get_virus_ct()
          # [ok: ncp_ct, ok: chip_ct] = Task.await_many([ncp_task, chips_task], :infinity)
          Logger.debug(["Ready\n", inspect(ready_data, pretty: true)])

          {"Bot Ready\n#{chip_ct} chips loaded\n#{virus_ct} viruses loaded\n#{ncp_ct} ncps loaded",
           false}
      end

    BnBBot.Util.dm_owner(dm_msg, override)
  end

  def handle_event({:RESUMED, resume_data, _ws_state}) do
    Logger.debug(["Bot resumed\n", inspect(resume_data, pretty: true)])
    BnBBot.Util.dm_owner("Bot Resumed")
  end

  # button clicks
  def handle_event({:INTERACTION_CREATE, %Nostrum.Struct.Interaction{type: 3} = inter, _ws_state}) do
    Logger.debug([
      "Got an interaction button click on #{inter.message.id}\n",
      inspect(inter, pretty: true)
    ])

    case inter.data.custom_id do
      #format is 6 hex digits, underscore, kind, underscore, name
      <<id::binary-size(6), "_", kind::utf8, "_", name::binary>> when kind in [?c, ?n, ?v] ->
        id = String.to_integer(id, 16)
        BnBBot.ButtonAwait.resp_to_btn(inter, id, {kind, name})

      <<id::binary-size(6), "_yn_", yn::binary>> when yn in ["yes", "no"] ->
        id = String.to_integer(id, 16)
        BnBBot.ButtonAwait.resp_to_btn(inter, id, yn)

      <<kind::utf8, "r_", name::binary>> when kind in [?c, ?n, ?v] ->
        BnBBot.ButtonAwait.resp_to_persistent_btn(inter, kind, name)

      <<"r_", id::binary>> ->
        BnBBot.RoleBtn.handle_role_btn_click(inter, id)

      _ ->
        BnBBot.ButtonAwait.resp_to_btn(inter, inter.message.id)
    end
  end

  # slash commands and context menu
  def handle_event({:INTERACTION_CREATE, %Nostrum.Struct.Interaction{type: 2} = inter, _ws_state}) do
    Logger.debug(["Got an interaction command\n", inspect(inter, pretty: true)])

    try do
      BnBBot.SlashCommands.handle_command(inter)
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))

        Api.create_message!(
          inter.channel_id,
          "An error has occurred, inform Major"
        )
    end
  end

  # autocomplete, gonna leave it up to the individual commands to handle both types if they have both
  def handle_event({:INTERACTION_CREATE, %Nostrum.Struct.Interaction{type: 4} = inter, _ws_state}) do
    Logger.debug(["Got an interaction autocomplete req\n", inspect(inter, pretty: true)])

    try do
      BnBBot.SlashCommands.handle_command(inter)
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))

        Api.create_message!(
          inter.channel_id,
          "An error has occurred, inform Major"
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
