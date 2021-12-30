defmodule BnBBot.Webhook.Update do
  @moduledoc """
  Functions that can be called by external nodes
  """

  alias Nostrum.Api

  require Logger

  @spec should_update?(String.t(), Nostrum.Snowflake.t()) :: boolean()
  def should_update?(msg, user_id) do
    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

    buttons = make_yes_no_buttons(uuid)

    dm_channel_id = BnBBot.Util.find_dm_channel_id(user_id)

    msg =
      Api.create_message!(dm_channel_id, %{
        content: msg,
        components: buttons
      })

    btn_response = BnBBot.ButtonAwait.await_btn_click(uuid, nil)

    case btn_response do
      {btn_inter, "yes"} ->
        Task.start(fn ->
          {:ok} =
            Api.create_interaction_response(btn_inter, %{
              type: 7,
              data: %{
                content: "Updating...",
                components: []
              }
            })
        end)

        true

      {btn_inter, "no"} ->
        Task.start(fn ->
          {:ok} =
            Api.create_interaction_response(btn_inter, %{
              type: 7,
              data: %{
                content: "Not updating.",
                components: []
              }
            })
        end)

        false

      nil ->
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

  @spec should_announce?(String.t(), Nostrum.Snowflake.t()) :: boolean
  def should_announce?(msg, user_id) do
    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

    buttons = make_yes_no_buttons(uuid)

    dm_channel_id = BnBBot.Util.find_dm_channel_id(user_id)

    msg =
      Api.create_message!(dm_channel_id, %{
        content: msg,
        components: buttons
      })

    btn_response = BnBBot.ButtonAwait.await_btn_click(uuid, nil)

    case btn_response do
      {btn_inter, "yes"} ->
        Task.start(fn ->
          {:ok} =
            Api.create_interaction_response(btn_inter, %{
              type: 7,
              data: %{
                content: "Announcing...",
                components: []
              }
            })
        end)

        true

      {btn_inter, "no"} ->
        Task.start(fn ->
          {:ok} =
            Api.create_interaction_response(btn_inter, %{
              type: 7,
              data: %{
                content: "Not announcing",
                components: []
              }
            })
        end)

        false

      nil ->
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

  defp make_yes_no_buttons(uuid) when uuid in 0..0xFF_FF_FF do
    uuid_str =
      uuid
      |> Integer.to_string(16)
      |> String.pad_leading(6, "0")

    yes = %{
      type: 2,
      style: 3,
      label: "yes",
      custom_id: "#{uuid_str}_yn_yes"
    }

    no = %{
      type: 2,
      style: 4,
      label: "no",
      custom_id: "#{uuid_str}_yn_no"
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
