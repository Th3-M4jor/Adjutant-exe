defmodule Adjutant.ButtonAwait do
  @moduledoc """
  Module for creating buttons that wait for a response from the user.
  """

  alias Nostrum.Api
  alias Nostrum.Struct.Component.{ActionRow, Button}

  require Logger

  def make_yes_no_buttons(uuid) when uuid in 0..0xFF_FF_FF do
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

  @spec get_confirmation?(Nostrum.Struct.Interaction.t(), String.t()) :: boolean()
  def get_confirmation?(inter, content) do
    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

    uuid_str =
      uuid
      |> Integer.to_string(16)
      |> String.pad_leading(6, "0")

    buttons =
      [
        Button.interaction_button("yes", "#{uuid_str}_yn_yes", style: 4),
        Button.interaction_button("no", "#{uuid_str}_yn_no", style: 2)
      ]
      |> ActionRow.action_row()
      |> List.wrap()

    :ok =
      Api.Interaction.create_response(
        inter,
        %{
          type: 4,
          data: %{
            content: content,
            flags: 64,
            components: buttons
          }
        }
      )

    btn_response = Adjutant.ButtonAwait.await_btn_click(uuid, nil)

    case btn_response do
      {btn_inter, yn} when yn in ["yes", "no"] ->
        Api.Interaction.create_response(btn_inter, %{
          type: 7,
          data: %{
            components: []
          }
        })

        yn == "yes"

      nil ->
        Api.Interaction.edit_response(inter, %{
          content: "Timed out waiting for response",
          components: []
        })

        false
    end
  end

  @doc """
  Awaits a button click on the given message from a user with the given ID (nil for any user)
  timeout is after 30 seconds
  """
  @spec await_btn_click(
          pos_integer() | Nostrum.Snowflake.t(),
          Nostrum.Snowflake.t() | nil,
          pos_integer()
        ) ::
          {Nostrum.Struct.Interaction.t(), any()}
          | Nostrum.Struct.Interaction.t()
          | nil
          | no_return()
  def await_btn_click(uuid, user_id \\ nil, timeout \\ 30_000) when uuid in 0..0xFF_FF_FF do
    Registry.register(:BUTTON_COLLECTOR, uuid, user_id)
    # Registry.register(:SHUTDOWN_REGISTRY, uuid, user_id)
    Logger.debug("Registering an await click on #{uuid} for #{user_id}")
    btn = await_btn_click_inner(timeout)
    Logger.debug("Got a response to #{uuid} of #{inspect(btn, pretty: true)}")
    Registry.unregister(:BUTTON_COLLECTOR, uuid)
    # Registry.unregister(:SHUTDOWN_REGISTRY, uuid)
    btn
  end

  @spec await_modal_input(pos_integer()) :: Nostrum.Struct.Interaction.t() | nil | no_return()
  def await_modal_input(uuid) when uuid in 0..0xFF_FF_FF do
    Registry.register(:BUTTON_COLLECTOR, uuid, nil)
    # Registry.register(:SHUTDOWN_REGISTRY, uuid, nil)
    Logger.debug("Registering an await modal input on #{uuid}")
    input = await_btn_click_inner(:timer.minutes(30))
    Logger.debug("Got a response to #{uuid} of #{inspect(input, pretty: true)}")
    Registry.unregister(:BUTTON_COLLECTOR, uuid)
    # Registry.unregister(:SHUTDOWN_REGISTRY, uuid)
    input
  end

  def resp_to_btn(%Nostrum.Struct.Interaction{} = inter, id, value \\ nil) do
    Logger.debug("Looking up uuid #{id}")

    case Registry.lookup(:BUTTON_COLLECTOR, id) do
      [{pid, user_id}]
      when is_nil(user_id)
      when inter.user.id == user_id
      when inter.member.user_id == user_id ->
        send(pid, {:btn_click, inter, value})

      _ ->
        Logger.debug("Interaction wasn't registered, or wasn't for said user")

        Api.Interaction.create_response(
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

  # default timeout is 30 seconds
  defp await_btn_click_inner(timeout) do
    receive do
      :shutdown ->
        nil

      value ->
        handle_btn_click(value)
    after
      timeout ->
        nil
    end
  end

  defp handle_btn_click({:btn_click, %Nostrum.Struct.Interaction{} = value, nil}) do
    value
  end

  defp handle_btn_click({:btn_click, %Nostrum.Struct.Interaction{} = value, data}) do
    {value, data}
  end

  defp handle_btn_click(other) do
    Logger.error("Recieved message that wasn't a btn click: #{inspect(other)}")
    raise "Inconcievable"
  end
end
