defmodule BnBBot.Supervisor do
  @moduledoc """
  Main entry point for the bot.
  """

  require Logger
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.debug("Starting Supervisor")

    button_collector = Registry.child_spec(keys: :unique, name: :BUTTON_COLLECTOR)

    children = [button_collector, BnBBot.Consumer]

    res = Supervisor.init(children, strategy: :one_for_one)
    Logger.debug("Supervisor started")
    # :ignore
    res
  end
end

defmodule BnBBot.Consumer do
  @moduledoc """
  This module is responsible for consuming events from the gateway.
  """

  require Logger
  use Nostrum.Consumer

  alias Nostrum.Api
  alias Nostrum.Struct.Event.Ready, as: ReadyEvent
  alias Nostrum.Struct.{Guild, Interaction, Message}

  @primary_guild_id :elixir_bot |> Application.compile_env!(:primary_guild_id)
  @primary_guild_channel_id :elixir_bot |> Application.compile_env!(:primary_guild_channel_id)
  @primary_guild_role_channel_id :elixir_bot
                                 |> Application.compile_env!(:primary_guild_role_channel_id)
  @log_channel_id :elixir_bot |> Application.compile_env!(:dm_log_id)

  # ignore bots
  def handle_event({:MESSAGE_CREATE, %Message{author: %{bot: true}}, _ws_state}) do
    :noop
  end

  def handle_event({:MESSAGE_CREATE, %Message{} = msg, _ws_state}) do
    if is_nil(msg.guild_id) do
      # log dms unless in guild
      Task.start(fn -> BnBBot.DmLogger.log_dm(msg) end)
    else
      # else see if we need to resolve a psycho effect
      Task.start(fn ->
        try do
          BnBBot.PsychoEffects.maybe_resolve_random_effect(msg)
          BnBBot.PsychoEffects.maybe_resolve_user_effect(msg)
        rescue
          e ->
            Logger.error(Exception.format(:error, e, __STACKTRACE__))
            BnBBot.Util.dm_owner("An error has occurred", true)
        end
      end)
    end

    BnBBot.Command.dispatch(msg)
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))

      Api.create_message(
        msg.channel_id,
        "An error has occurred, inform Major\n#{Exception.message(e)}"
      )
  end

  def handle_event({:GUILD_MEMBER_ADD, {guild_id, %Guild.Member{} = member}, _ws_state}) do
    if guild_id == @primary_guild_id do
      text = "Welcome to the Busters & Battlechips Discord <@#{member.user_id}>. \
        Assign yourself roles in <##{@primary_guild_role_channel_id}>"

      Api.create_message!(@primary_guild_channel_id, text)
    end
  end

  def handle_event({:GUILD_MEMBER_REMOVE, {guild_id, %Guild.Member{} = member}, _ws_state}) do
    text = "#{member.user_id} has left #{guild_id}"
    Api.create_message!(@log_channel_id, text)
  end

  def handle_event({:READY, %ReadyEvent{} = ready_data, _ws_state}) do
    Logger.debug("Bot ready")

    Api.update_status(:online, "Now with Slash Commands")

    {dm_msg, override} =
      case :persistent_term.get({:bnb_bot_data, :first_ready}, nil) do
        false ->
          Logger.warning(["Ready re-emitted\n", inspect(ready_data, pretty: true)])
          {"ready re-emitted", true}

        _ ->
          :persistent_term.put({:bnb_bot_data, :first_ready}, false)
          Oban.resume_queue(queue: :remind_me)
          Oban.resume_queue(queue: :edit_message)

          chip_ct = BnBBot.Library.Battlechip.get_chip_ct()
          ncp_ct = BnBBot.Library.NCP.get_ncp_ct()
          virus_ct = BnBBot.Library.Virus.get_virus_ct()

          Logger.debug(["Ready\n", inspect(ready_data, pretty: true)])
          BnBBot.Command.setup_commands()

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
  def handle_event({:INTERACTION_CREATE, %Interaction{type: 3} = inter, _ws_state}) do
    Logger.debug([
      "Got an interaction button click on #{inter.message.id}\n",
      inspect(inter, pretty: true)
    ])

    case inter.data.custom_id do
      # format is 6 hex digits, underscore, kind, underscore, name
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

  # modals
  def handle_event({:INTERACTION_CREATE, %Interaction{type: 5} = inter, _ws_state}) do
    Logger.debug(["Got a Modal submit\n", inspect(inter, pretty: true)])
    id = String.to_integer(inter.data.custom_id, 16)
    BnBBot.ButtonAwait.resp_to_btn(inter, id)
  end

  # slash commands and context menu
  def handle_event({:INTERACTION_CREATE, %Interaction{type: 2} = inter, _ws_state}) do
    Logger.debug(["Got an interaction command\n", inspect(inter, pretty: true)])
    BnBBot.Command.dispatch(inter)
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))

      Api.create_message(
        inter.channel_id,
        "An error has occurred, inform Major\n#{Exception.message(e)}"
      )
  end

  # autocomplete, gonna leave it up to the individual commands to handle both types if they have both
  def handle_event({:INTERACTION_CREATE, %Interaction{type: 4} = inter, _ws_state}) do
    Logger.debug(["Got an interaction autocomplete req\n", inspect(inter, pretty: true)])

    BnBBot.Command.dispatch(inter)
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))

      Api.create_message(
        inter.channel_id,
        "An error has occurred, inform Major\n#{Exception.message(e)}"
      )
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(_event) do
    :noop
  end

  # overriding the default handle_info to handle events
  # so we can catch errors and log them
  def handle_info({:event, event}, state) do
    Task.start_link(fn ->
      try do
        handle_event(event)
      rescue
        e ->
          Logger.error(Exception.format(:error, e, __STACKTRACE__))

          BnBBot.Util.dm_owner(
            "An error has occurred, inform Major\n#{Exception.message(e)}",
            true
          )
      end
    end)

    {:noreply, state}
  end
end
