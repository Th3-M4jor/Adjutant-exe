defmodule BnBBot.Commands.Chip do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.SlashCmdFn

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

  defp make_btn_response(%Nostrum.Struct.Interaction{} = inter, []) do
    Api.create_interaction_response(inter, %{
      type: 4,
      data: %{
        content: "I'm sorry, there are no chips with a similar name",
        flags: 64
      }
    })
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
