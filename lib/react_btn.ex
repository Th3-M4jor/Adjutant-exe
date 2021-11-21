defmodule BnBBot.ButtonAwait do
  require Logger
  # alias Nostrum.Api

  @doc """
  First string in the tuple is the Name on the button
  Second string is the id of the button
  integer is the style of the button

  Raises if there are more than 25 buttons
  """
  @spec generate_msg_buttons([struct()], boolean()) ::
          [
            %{
              type: pos_integer(),
              components: [BnBBot.Library.LibObj.button() | BnBBot.Library.LibObj.link_button()]
            }
          ]
          | no_return()
  def generate_msg_buttons(buttons, disabled \\ false)

  def generate_msg_buttons([], _disabled) do
    raise "Empty List"
  end

  def generate_msg_buttons(content, _disabled) when length(content) > 25 do
    raise "Too many buttons"
  end

  def generate_msg_buttons(content, disabled) do
    row_chunks = Enum.chunk_every(content, 5)

    Enum.map(row_chunks, fn row ->
      action_row = Enum.map(row, &BnBBot.Library.LibObj.to_btn(&1, disabled))

      %{
        type: 1,
        components: action_row
      }
    end)
  end

  @spec generate_msg_buttons_with_uuid([struct()], boolean(), pos_integer()) ::
          [
            %{
              type: pos_integer(),
              components: [BnBBot.Library.LibObj.button() | BnBBot.Library.LibObj.link_button()]
            }
          ]
          | no_return()

  def generate_msg_buttons_with_uuid(buttons, disabled \\ false, uuid)

  def generate_msg_buttons_with_uuid([], _disabled, _uuid) do
    raise "Empty List"
  end

  def generate_msg_buttons_with_uuid(content, _disabled, _uuid) when length(content) > 25 do
    raise "Too many buttons"
  end

  def generate_msg_buttons_with_uuid(content, disabled, uuid) do
    # uuid = System.unique_integer([:positive]) |> rem(1000)
    row_chunks = Enum.chunk_every(content, 5)

    Enum.map(row_chunks, fn row ->
      action_row = Enum.map(row, &BnBBot.Library.LibObj.to_btn_with_uuid(&1, disabled, uuid))

      %{
        type: 1,
        components: action_row
      }
    end)
  end

  @spec generate_persistent_buttons([struct()], boolean()) ::
          [
            %{
              type: pos_integer(),
              components: [BnBBot.Library.LibObj.button() | BnBBot.Library.LibObj.link_button()]
            }
          ]
          | no_return()
  def generate_persistent_buttons(buttons, disabled \\ false)

  def generate_persistent_buttons([], _disabled) do
    raise "Empty List"
  end

  def generate_persistent_buttons(content, _disabled) when length(content) > 25 do
    raise "Too many buttons"
  end

  def generate_persistent_buttons(content, disabled) do
    row_chunks = Enum.chunk_every(content, 5)

    Enum.map(row_chunks, fn row ->
      action_row = Enum.map(row, &BnBBot.Library.LibObj.to_persistent_btn(&1, disabled))

      %{
        type: 1,
        components: action_row
      }
    end)
  end

  @spec get_confirmation?(Nostrum.Struct.Interaction.t(), String.t()) :: boolean()
  def get_confirmation?(inter, content) do
    uuid = System.unique_integer([:positive]) |> rem(1000)

    action_row = [
      %{
        type: 2,
        style: 4,
        label: "yes",
        custom_id: "yn_#{uuid}_yes"
      },
      %{
        type: 2,
        style: 2,
        label: "no",
        custom_id: "yn_#{uuid}_no"
      }
    ]

    buttons = [
      %{
        type: 1,
        components: action_row
      }
    ]

    {:ok} =
      Nostrum.Api.create_interaction_response(
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

    btn_response = BnBBot.ButtonAwait.await_btn_click(uuid, nil)

    unless is_nil(btn_response) do
      Nostrum.Api.create_interaction_response(btn_response, %{
        type: 7,
        data: %{
          components: []
        }
      })

      case String.split(btn_response.data.custom_id, "_") do
        [_, _, "yes"] ->
          true

        [_, _, "no"] ->
          false
      end
    else
      #route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

      Nostrum.Api.edit_interaction_response(inter, %{
        content: "Timed out waiting for response",
        components: []
      })

      false
    end
  end

  #  defp tuple_to_btn({name, id, style}) do
  #    %{
  #      type: 2,
  #      style: style,
  #      label: name,
  #      custom_id: id
  #    }
  #  end

  @doc """
  Awaits a button click on the given message from a user with the given ID (nil for any user)
  timeout is after 30 seconds
  """
  @spec await_btn_click(pos_integer() | Nostrum.Snowflake.t(), Nostrum.Snowflake.t() | nil) ::
          %Nostrum.Struct.Interaction{} | nil | no_return()
  def await_btn_click(uuid, user_id \\ nil) do
    Registry.register(:BUTTON_COLLECTOR, uuid, user_id)
    Logger.debug("Registering an await click on #{uuid} for #{user_id}")
    btn = await_btn_click_inner()
    Logger.debug("Got a response to #{uuid} of #{inspect(btn, pretty: true)}")
    Registry.unregister(:BUTTON_COLLECTOR, uuid)
    btn
  end

  def resp_to_btn(%Nostrum.Struct.Interaction{} = inter, id) do
    case Registry.lookup(:BUTTON_COLLECTOR, id) do
      [{pid, user_id}]
      when is_nil(user_id)
      when inter.user.id == user_id
      when inter.member.user.id == user_id ->
        send(pid, {:btn_click, inter})

      _ ->
        Logger.debug("Interaction wasn't registered, or wasn't for said user")

        {:ok} =
          Nostrum.Api.create_interaction_response(
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

  def resp_to_persistent_btn(%Nostrum.Struct.Interaction{} = inter, kind, name) do
    {:found, obj} =
      case kind do
        ?c -> BnBBot.Library.Battlechip.get_chip(name)
        ?n -> BnBBot.Library.NCP.get_ncp(name)
        ?v -> BnBBot.Library.Virus.get_virus(name)
      end

    {:ok} =
      Nostrum.Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: "#{obj}"
          }
        }
      )
  end

  defp await_btn_click_inner() do
    receive do
      value ->
        handle_btn_click(value)
    after
      # after 30 seconds, timeout
      30_000 ->
        nil
    end
  end

  defp handle_btn_click({:btn_click, %Nostrum.Struct.Interaction{} = value}) do
    value
  end

  defp handle_btn_click(other) do
    Logger.error("Recieved message that wasn't a btn click: #{inspect(other)}")
    raise "Inconcievable"
  end
end
