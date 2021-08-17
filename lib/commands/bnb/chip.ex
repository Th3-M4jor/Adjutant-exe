defmodule BnBBot.Commands.Chip do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.CommandFn

  def help() do
    {"chip", :everyone, "Get info about a battlechip"}
  end

  def get_name() do
    "chip"
  end

  def full_help() do
    "Search for a chip with the given name, returns full data on it"
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, []) do
    Logger.debug("Recieved a chip command with no arguments")

    Api.create_message(
      msg.channel_id,
      content: "You must provide a name as an argument",
      message_reference: %{message_id: msg.id}
    )
  end

  def call(%Nostrum.Struct.Message{} = msg, name_list) do
    name = Enum.join(name_list, " ")
    Logger.debug("Searching for the following chip: #{name}")

    case BnBBot.Library.Battlechip.get_chip(name) do
      {:found, chip} ->
        Api.create_message(
          msg.channel_id,
          content: "#{chip}",
          message_reference: %{message_id: msg.id}
        )

      {:not_found, possibilities} ->
        handle_not_found(msg, possibilities)
    end
  end

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    [opt] = inter.data.options
    name = opt.value
    Logger.debug(["Searching for the following chip: ", name])

    case BnBBot.Library.Battlechip.get_chip(name) do
      {:found, chip} ->
        Api.create_interaction_response(
          inter,
          %{
            type: 4,
            content: to_string(chip)
          }
        )

      {:not_found, possibilities} ->
        handle_not_found(inter, possibilities)
    end
  end

  def get_create_map() do
    %{
      type: 1,
      name: "chip",
      description: "Search for a chip with the given name, returns full data on it",
      options: [
        %{
          type: 3,
          name: "name",
          description: "The name of the chip to search for",
          required: true,
        }
      ]
    }
  end

  defp handle_not_found(msg_inter, possibilities) do
    Logger.debug("No chip found, showing suggestions")

    # remove all whose similarity is less than 0.7
    filtered_opts = Enum.filter(possibilities, fn {dist, _} -> dist >= 0.7 end)

    make_btn_response(msg_inter, filtered_opts)
  end

  defp make_btn_response(%Nostrum.Struct.Message{} = msg, []) do
    Api.create_message!(msg.channel_id,
      content: "I'm sorry, there are no chips with a similar name",
      message_reference: %{message_id: msg.id}
    )
  end

  defp make_btn_response(%Nostrum.Struct.Interaction{} = inter, []) do
    Api.create_interaction_response(inter, %{
      type: 4,
      data: %{
        content: "I'm sorry, there are no chips with a similar name",
        flags: 64
      }
    })
  end

  defp make_btn_response(%Nostrum.Struct.Message{} = msg, filtered_opts) do
    chip_list = Enum.map(filtered_opts, fn {_, chip} -> chip end)

    buttons = BnBBot.ButtonAwait.generate_msg_buttons(chip_list)

    resp =
      Api.create_message!(msg.channel_id,
        content: "Did you mean:",
        message_reference: %{message_id: msg.id},
        components: buttons
      )

    btn_resp = BnBBot.ButtonAwait.await_btn_click(resp.id, msg.author.id)

    unless is_nil(btn_resp) do
      ["c", chip] = String.split(btn_resp.data.custom_id, "_", parts: 2)
      {:found, chip} = BnBBot.Library.Battlechip.get_chip(chip)

      {:ok} =
        Api.create_interaction_response(
          btn_resp,
          %{
            type: 7,
            data: %{
              content: "#{chip}",
              components: []
            }
          }
        )
    else
      Api.edit_message!(resp,
        content: "Timed out waiting for response",
        components: []
      )
    end
  end

  defp make_btn_response(%Nostrum.Struct.Interaction{} = inter, filtered_opts) do
    chip_list = Enum.map(filtered_opts, fn {_, chip} -> chip end)
    uuid = System.unique_integer([:positive]) |> rem(1000)
    buttons = BnBBot.ButtonAwait.generate_msg_buttons_with_uuid(chip_list, uuid)

    Api.create_interaction_response(
      inter,
      %{
        type: 4,
        data: %{
          content: "Did you mean:",
          flags: 64,
          components: buttons
        }
      }
    )

    btn_response = BnBBot.ButtonAwait.await_btn_click(uuid, nil)
    route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

    unless is_nil(btn_response) do
      [_uuid, "c", chip] = String.split(btn_response.data.custom_id, "_", parts: 3)
      {:found, chip} = BnBBot.Library.Battlechip.get_chip(chip)

      edit_task =
        Task.async(fn ->
          Api.request(:patch, route, %{
            content: "You selected #{chip.name}",
            components: []
          })
        end)

      resp_task =
        Task.async(fn ->

          resp_text = if is_nil(inter.user) do
            "<@#{inter.member.user.id}> used `/chip`\n#{chip}"
          else
            "<@#{inter.user.id}> used `/chip`\n#{chip}"
          end

          Api.execute_webhook(inter.application_id, inter.token, %{
            content: resp_text
          })
        end)

      Task.await_many([edit_task, resp_task], :infinity)
    else
      Api.request(:patch, route, %{
        content: "Timed out waiting for response",
        components: []
      })
    end
  end
end
