defmodule BnBBot.Supervisor do
  @moduledoc """
  Main entry point for the bot.
  """

  require Logger
  use Supervisor
  # use Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)

    # Registry.start_link(keys: :unique, name: :REACTION_COLLECTOR)
    # Registry.start_link(keys: :unique, name: :BUTTON_COLLECTOR)
  end

  @impl true
  def init(_init_arg) do
    Logger.debug("Starting Supervisor")

    button_collector = Registry.child_spec(keys: :unique, name: :BUTTON_COLLECTOR)

    bot_data =
      Supervisor.child_spec(
        {BnBBot.Util.KVP, []},
        id: {:bnb_bot, :bnb_bot_data},
        restart: :transient
      )

    children = [button_collector, bot_data, BnBBot.Consumer]

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
  # use Nostrum.Consumer
  use GenServer

  alias Nostrum.Api
  alias Nostrum.Struct.Event.Ready, as: ReadyEvent
  alias Nostrum.Struct.{Guild, Interaction, Message}

  @primary_guild_id :elixir_bot |> Application.compile_env!(:primary_guild_id)
  @primary_guild_channel_id :elixir_bot |> Application.compile_env!(:primary_guild_channel_id)
  @primary_guild_role_channel_id :elixir_bot
                                 |> Application.compile_env!(:primary_guild_role_channel_id)
  @log_channel_id :elixir_bot |> Application.compile_env!(:dm_log_id)

  # Note: erlang atomic arrays are 1-indexed based
  #
  # Slot 1 holds the unix time in seconds
  # of the last time a random effect was resolved
  #
  # Slot 2 holds the id of the user who got the effect
  #
  # Slot 3 holds the enum of the effect for the effected user
  # if the effect is one that happens over time
  @atomic_slot_count 3

  # ignore bots
  def handle_event({:MESSAGE_CREATE, %Message{author: %{bot: true}}, _ws_state}, _ref) do
    :noop
  end

  def handle_event({:MESSAGE_CREATE, %Message{} = msg, _ws_state}, ref) do
    if is_nil(msg.guild_id) do
      Task.start(fn -> BnBBot.DmLogger.log_dm(msg) end)
    end

    Task.start(fn ->
      BnBBot.PsychoEffects.maybe_resolve_random_effect(msg, ref)
      BnBBot.PsychoEffects.maybe_resolve_user_effect(msg, ref)
    end)

    BnBBot.Command.dispatch(msg)
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))

      Api.create_message(
        msg.channel_id,
        "An error has occurred, inform Major\n#{Exception.message(e)}"
      )
  end

  def handle_event({:GUILD_MEMBER_ADD, {guild_id, %Guild.Member{} = member}, _ws_state}, _ref) do
    if guild_id == @primary_guild_id do
      text = "Welcome to the Busters & Battlechips Discord <@#{member.user_id}>. \
        Assign yourself roles in <##{@primary_guild_role_channel_id}>"

      Api.create_message!(@primary_guild_channel_id, text)
    end
  end

  def handle_event({:GUILD_MEMBER_REMOVE, {guild_id, %Guild.Member{} = member}, _ws_state}, _ref) do
    text = "#{member.user_id} has left #{guild_id}"
    Api.create_message!(@log_channel_id, text)
  end

  def handle_event({:READY, %ReadyEvent{} = ready_data, _ws_state}, _ref) do
    Logger.debug("Bot ready")

    Api.update_status(:online, "Now with Slash Commands")

    {dm_msg, override} =
      case GenServer.call(:bnb_bot_data, {:get, :first_ready}) do
        false ->
          Logger.warn(["Ready re-emitted\n", inspect(ready_data, pretty: true)])
          {"ready re-emitted", true}

        _ ->
          GenServer.cast(:bnb_bot_data, {:insert, :first_ready, false})
          reminder_queue_name = :elixir_bot |> Application.fetch_env!(:remind_me_queue)
          Oban.resume_queue(queue: reminder_queue_name)
          edit_queue_name = :elixir_bot |> Application.fetch_env!(:edit_message_queue)
          Oban.resume_queue(queue: edit_queue_name)

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

  def handle_event({:RESUMED, resume_data, _ws_state}, _ref) do
    Logger.debug(["Bot resumed\n", inspect(resume_data, pretty: true)])
    BnBBot.Util.dm_owner("Bot Resumed")
  end

  # button clicks
  def handle_event({:INTERACTION_CREATE, %Interaction{type: 3} = inter, _ws_state}, _ref) do
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
  def handle_event({:INTERACTION_CREATE, %Interaction{type: 5} = inter, _ws_state}, _ref) do
    Logger.debug(["Got a Modal submit\n", inspect(inter, pretty: true)])
    id = String.to_integer(inter.data.custom_id, 16)
    BnBBot.ButtonAwait.resp_to_btn(inter, id)
  end

  # slash commands and context menu
  def handle_event({:INTERACTION_CREATE, %Interaction{type: 2} = inter, _ws_state}, _ref) do
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
  def handle_event({:INTERACTION_CREATE, %Interaction{type: 4} = inter, _ws_state}, _ref) do
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
  def handle_event(_event, _ref) do
    :noop
  end

  # GenServer Callbacks
  # using a custom Nostrum.Consumer impl
  # since we want to inject custom state
  # into the event handlers
  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    # create a new atomic array of size @atomic_slot_count
    # all unsigned integers default to 0
    atomics_ref = :atomics.new(@atomic_slot_count, signed: false)
    {:ok, atomics_ref, {:continue, nil}}
  end

  def handle_continue(_args, state) do
    Nostrum.ConsumerGroup.join(self())
    {:noreply, state}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      max_restarts: 0,
      shutdown: 500
    }
  end

  def handle_info({:event, event}, state) do
    Task.start_link(fn ->
      try do
        handle_event(event, state)
      rescue
        e ->
          Logger.error(Exception.format(:error, e, __STACKTRACE__))
      end
    end)

    {:noreply, state}
  end
end
