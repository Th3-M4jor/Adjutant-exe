defmodule BnBBot.Commands.NCP do
  require Logger

  alias Nostrum.Api
  alias BnBBot.Library.NCP

  @behaviour BnBBot.SlashCmdFn

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    [sub_cmd] = inter.data.options

    case sub_cmd.name do
      "search" ->
        [opt] = sub_cmd.options
        name = opt.value
        search_ncp(inter, name)

      "color" ->
        [opt] = sub_cmd.options
        name = opt.value
        color = String.to_existing_atom(name)
        ncps = NCP.get_ncps_by_color(color)
        send_ncp_color(inter, color, ncps)
    end

    :ignore
  end

  def get_create_map() do
    color_choices =
      Enum.map(["White", "Pink", "Yellow", "Green", "Blue", "Red", "Gray"], fn name ->
        %{
          name: name,
          value: String.downcase(name, :ascii)
        }
      end)

    %{
      type: 1,
      name: "ncp",
      description: "The NCP group",
      options: [
        %{
          type: 1,
          name: "search",
          description: "Search for a particular NCP",
          options: [
            %{
              type: 3,
              name: "name",
              description: "The name of the NCP to search for",
              required: true
            }
          ]
        },
        %{
          type: 1,
          name: "color",
          description: "Get all NCPs of a particular color",
          options: [
            %{
              type: 3,
              name: "color",
              description: "The color of the NCPs to search for",
              required: true,
              choices: color_choices
            }
          ]
        }
      ]
    }
  end

  defp search_ncp(inter, name) do
    Logger.debug(["Searching for the following NCP: ", name])

    case BnBBot.Library.NCP.get_ncp(name) do
      {:found, ncp} ->
        send_found_ncp(inter, ncp)

      {:not_found, possibilities} ->
        handle_not_found_ncp(inter, possibilities)
    end
  end

  defp send_ncp_color(inter, color, []) do
    Logger.debug(["No NCPs found for color: ", color])

    color_str = to_string(color) |> String.capitalize(:ascii)

    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: "There are no #{color_str} NCPs",
            flags: 64
          }
        }
      )

  end

  defp send_ncp_color(inter, color, ncps) do
    buttons = BnBBot.ButtonAwait.generate_persistent_buttons(ncps)

    color_str = to_string(color) |> String.capitalize(:ascii)

    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: "These are the #{color_str} NCPs:",
            components: buttons
          }
        }
      )

    Process.sleep(300000) # five minutes

    names = Enum.map(ncps, fn ncp ->
      ncp.name
    end) |> Enum.join(", ")

    route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

    Api.request(:patch, route, %{
      content: "These are the #{color_str} NCPs:\n#{names}",
      components: []
    })

  end

  defp send_found_ncp(%Nostrum.Struct.Interaction{} = inter, %BnBBot.Library.NCP{} = ncp) do
    {:ok} =
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: to_string(ncp)
        }
      })
  end

  defp handle_not_found_ncp(inter, opts) do
    Logger.debug("handling a not found ncp")

    BnBBot.Commands.All.do_btn_response(inter, opts)
  end
end
