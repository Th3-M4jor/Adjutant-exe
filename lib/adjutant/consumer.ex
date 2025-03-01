defmodule Adjutant.Consumer do
  @moduledoc """
  This module is responsible for consuming events from the gateway.
  """

  require Logger
  @behaviour Nostrum.Consumer

  alias Nostrum.Api
  alias Nostrum.Struct.Event.Ready, as: ReadyEvent
  alias Nostrum.Struct.{Guild, Interaction, Message}

  @primary_guild_id Application.compile_env!(:adjutant, :primary_guild_id)
  @primary_guild_channel_id Application.compile_env!(:adjutant, :primary_guild_channel_id)
  @primary_guild_role_channel_id Application.compile_env!(
                                   :adjutant,
                                   :primary_guild_role_channel_id
                                 )
  @log_channel_id Application.compile_env!(:adjutant, :dm_log_id)

  def handle_event(event) do
    handle_event_inner(event)
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))

      Adjutant.Util.dm_owner(
        "An error has occurred, inform Major\n#{Exception.message(e)}",
        true
      )
  end

  # ignore webhooks
  defp handle_event_inner({:MESSAGE_CREATE, %Message{webhook_id: webhook_id}, _ws_state})
       when webhook_id != nil do
    :noop
  end

  # ignore bots
  defp handle_event_inner({:MESSAGE_CREATE, %Message{author: %{bot: true}}, _ws_state}) do
    :noop
  end

  defp handle_event_inner({:MESSAGE_CREATE, %Message{guild_id: nil} = msg, _ws_state}) do
    Task.start(fn -> Adjutant.DmLogger.log_dm(msg) end)

    Adjutant.Command.dispatch(msg)
  end

  defp handle_event_inner({:MESSAGE_CREATE, %Message{} = msg, _ws_state}) do
    Adjutant.Command.dispatch(msg)
  end

  defp handle_event_inner({:MESSAGE_UPDATE, {nil, new_msg}, _ws_state}) do
    Logger.debug("Got a message update event and the old was not cached\n#{inspect(new_msg)}")
  end

  defp handle_event_inner({:MESSAGE_UPDATE, {old_msg, new_msg}, _ws_state}) do
    Logger.debug("Got a message update event\n#{inspect(old_msg)}\n#{inspect(new_msg)}")
  end

  defp handle_event_inner({:MESSAGE_DELETE, %{deleted_message: nil}, _ws_state}) do
    Logger.debug("Got a message delete event and the message was not cached")
  end

  defp handle_event_inner({:MESSAGE_DELETE, %{deleted_message: msg}, _ws_state}) do
    Logger.debug("Got a message delete event and the message was cached\n#{inspect(msg)}")
  end

  defp handle_event_inner(
         {:GUILD_MEMBER_ADD, {@primary_guild_id, %Guild.Member{} = member}, _ws_state}
       ) do
    text = "Welcome to the Busters & Battlechips Discord <@#{member.user_id}>. \
        Assign yourself roles in <##{@primary_guild_role_channel_id}>"

    {:ok, _} = Api.Message.create(@primary_guild_channel_id, text)
  end

  defp handle_event_inner({:GUILD_MEMBER_REMOVE, {guild_id, %Guild.Member{} = member}, _ws_state}) do
    text = "#{member.user_id} has left #{guild_id}"
    {:ok, _} = Api.Message.create(@log_channel_id, text)
  end

  defp handle_event_inner({:READY, %ReadyEvent{} = ready_data, _ws_state}) do
    Logger.debug("Bot ready")

    Api.Self.update_status(:online, {:custom, "Now with Slash Commands"})

    {dm_msg, override} =
      case :persistent_term.get({:bnb_bot_data, :first_ready}, nil) do
        false ->
          Logger.warning(["Ready re-emitted\n", inspect(ready_data, pretty: true)])
          {"ready re-emitted", true}

        _ ->
          :persistent_term.put({:bnb_bot_data, :first_ready}, false)
          Oban.resume_queue(queue: :remind_me)
          Oban.resume_queue(queue: :edit_message)

          Logger.debug(["Ready\n", inspect(ready_data, pretty: true)])
          Adjutant.Command.setup_commands()

          {"Bot Ready", false}
      end

    Adjutant.Util.dm_owner(dm_msg, override)
  end

  defp handle_event_inner({:RESUMED, resume_data, _ws_state}) do
    Logger.debug(["Bot resumed\n", inspect(resume_data, pretty: true)])
    Adjutant.Util.dm_owner("Bot Resumed")
  end

  # button clicks
  defp handle_event_inner({:INTERACTION_CREATE, %Interaction{type: 3} = inter, _ws_state}) do
    Logger.debug([
      "Got an interaction button click on #{inter.message.id}\n",
      inspect(inter, pretty: true)
    ])

    case inter.data.custom_id do
      # format is 6 hex digits, underscore, kind, underscore, name
      <<id::binary-size(6), "_", kind::utf8, "_", name::binary>> when kind in [?c, ?n, ?v] ->
        id = String.to_integer(id, 16)
        Adjutant.ButtonAwait.resp_to_btn(inter, id, {kind, name})

      <<id::binary-size(6), "_yn_", yn::binary>> when yn in ["yes", "no"] ->
        id = String.to_integer(id, 16)
        Adjutant.ButtonAwait.resp_to_btn(inter, id, yn)

      <<"r_", id::binary>> ->
        Adjutant.RoleBtn.handle_role_btn_click(inter, id)

      _ ->
        Adjutant.ButtonAwait.resp_to_btn(inter, inter.message.id)
    end
  end

  # modals
  defp handle_event_inner({:INTERACTION_CREATE, %Interaction{type: 5} = inter, _ws_state}) do
    Logger.debug(["Got a Modal submit\n", inspect(inter, pretty: true)])
    id = String.to_integer(inter.data.custom_id, 16)
    Adjutant.ButtonAwait.resp_to_btn(inter, id)
  end

  # slash commands and context menu
  defp handle_event_inner({:INTERACTION_CREATE, %Interaction{type: 2} = inter, _ws_state}) do
    Logger.debug(["Got an interaction command\n", inspect(inter, pretty: true)])
    Adjutant.Command.dispatch(inter)
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))

      Api.Message.create(
        inter.channel_id,
        "An error has occurred, inform Major\n#{Exception.message(e)}"
      )
  end

  # autocomplete, gonna leave it up to the individual commands to handle both types if they have both
  defp handle_event_inner({:INTERACTION_CREATE, %Interaction{type: 4} = inter, _ws_state}) do
    Logger.debug(["Got an interaction autocomplete req\n", inspect(inter, pretty: true)])

    Adjutant.Command.dispatch(inter)
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))

      Api.Message.create(
        inter.channel_id,
        "An error has occurred, inform Major\n#{Exception.message(e)}"
      )
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  defp handle_event_inner(_event) do
    :noop
  end
end
