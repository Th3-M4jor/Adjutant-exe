defmodule BnBBot.Commands.Chip do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.SlashCmdFn

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    [sub_cmd] = inter.data.options

    case sub_cmd.name do
      "search" ->
        [opt] = sub_cmd.options
        name = opt.value
        search_chip(inter, name)
    end
  end

  def get_create_map() do
    %{
      type: 1,
      name: "chip",
      description: "The chip group",
      options: [
        %{
          type: 1,
          name: "search",
          description: "Search for a particular chip",
          options: [
            %{
              type: 3,
              name: "name",
              description: "The name of the chip to search for",
              required: true
            }
          ]
        }
      ]
    }
  end

  def search_chip(inter, name) do
    Logger.debug(["Searching for the following chip: ", name])

    case BnBBot.Library.Battlechip.get_chip(name) do
      {:found, chip} ->
        Logger.debug(["Found the following chip: ", chip.name])
        send_found_chip(inter, chip)

      {:not_found, possibilities} ->
        handle_not_found(inter, possibilities)
    end
  end

  def send_found_chip(%Nostrum.Struct.Interaction{} = inter, %BnBBot.Library.Battlechip{} = chip) do
    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: to_string(chip)
          }
        }
      )
  end

  defp handle_not_found(inter, opts) do
    Logger.debug("No chip found, showing suggestions")

    BnBBot.Commands.All.do_btn_response(inter, opts)
  end
end
