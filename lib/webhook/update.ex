defmodule BnBBot.Webhook.Update do
  alias Nostrum.Api

  require Logger

  @spec should_update?(String.t(), Nostrum.Snowflake.t()) :: boolean()
  def should_update?(msg, user_id) do
    try do
      uuid = System.unique_integer([:positive]) |> rem(1000)

      buttons = make_yes_no_buttons(uuid)

      dm_channel_id = BnBBot.Util.find_dm_channel_id(user_id)

      msg =
        Api.create_message!(dm_channel_id, %{
          content: msg,
          components: buttons
        })

      btn_response = BnBBot.ButtonAwait.await_btn_click(uuid, nil)

      unless is_nil(btn_response) do
        {should_update, resp} =
          case String.split(btn_response.data.custom_id, "_", parts: 3) do
            [_, "yes", _] ->
              {true, "Updating..."}

            [_, "no", _] ->
              {false, "Not updating"}

            _ ->
              Logger.debug("Invalid custom_id? assuming false")
              {false, "An error occurred, please inform Major"}
          end

        Task.start(fn ->
          {:ok} =
            Api.create_interaction_response(btn_response, %{
              type: 7,
              data: %{
                content: resp,
                components: []
              }
            })
        end)

        should_update
      else
        Logger.debug("No response received, assuming false")

        Task.start(fn ->
          Api.edit_message!(msg, %{
            content: "Timed out waiting for response, assuming No",
            components: []
          })
        end)

        false
      end
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        false
    end
  end

  @spec should_announce?(String.t(), Nostrum.Snowflake.t()) :: boolean
  def should_announce?(msg, user_id) do
    try do
      uuid = System.unique_integer([:positive]) |> rem(1000)

      buttons = make_yes_no_buttons(uuid)

      dm_channel_id = BnBBot.Util.find_dm_channel_id(user_id)

      msg =
        Api.create_message!(dm_channel_id, %{
          content: msg,
          components: buttons
        })

      btn_response = BnBBot.ButtonAwait.await_btn_click(uuid, nil)

      unless is_nil(btn_response) do
        {should_announce, resp} =
          case String.split(btn_response.data.custom_id, "_", parts: 3) do
            [_, "yes", _] ->
              {true, "Announcing..."}

            [_, "no", _] ->
              {false, "Not announcing"}

            _ ->
              Logger.debug("Invalid custom_id? assuming false")
              {false, "An error occurred, please inform Major"}
          end

        Task.start(fn ->
          {:ok} =
            Api.create_interaction_response(btn_response, %{
              type: 7,
              data: %{
                content: resp,
                components: []
              }
            })
        end)

        should_announce
      else
        Logger.debug("No response received, assuming false")

        Task.start(fn ->
          Api.edit_message!(msg, %{
            content: "Timed out waiting for response, assuming No",
            components: []
          })
        end)

        false
      end
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        false
    end
  end

  @spec announce(non_neg_integer | Nostrum.Struct.Message.t(), binary | keyword | map) ::
          Nostrum.Struct.Message.t()
  def announce(channel_id, content) do
    Api.create_message!(channel_id, content)
  end

  @spec dm_error(binary | keyword | map, non_neg_integer) :: Nostrum.Struct.Message.t()
  def dm_error(msg, user_id) do
    dm_channel_id = BnBBot.Util.find_dm_channel_id(user_id)

    Api.create_message!(dm_channel_id, msg)
  end

  defp make_yes_no_buttons(uuid) do
    yes = %{
      type: 2,
      style: 3,
      label: "yes",
      custom_id: "#{uuid}_yes_btn"
    }

    no = %{
      type: 2,
      style: 4,
      label: "no",
      custom_id: "#{uuid}_no_btn"
    }

    action_row = %{
      type: 1,
      components: [
        yes,
        no
      ]
    }

    [action_row]
  end
end
