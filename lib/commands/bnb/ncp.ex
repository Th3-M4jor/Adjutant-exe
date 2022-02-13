defmodule BnBBot.Commands.NCP do
  @moduledoc """
  Contains all NCP related commands.

  Currently, there are:

  `search` - Searches for a NCP.

  `color` - Lists all NCPs of a given color

  `starter` - Lists all NCPs that a particular element can select at the start.
  """

  require Logger

  alias BnBBot.Library.NCP
  alias Nostrum.Api

  use BnBBot.SlashCmdFn, permissions: :everyone

  @elements [
    "Fire",
    "Aqua",
    "Elec",
    "Wood",
    "Wind",
    "Sword",
    "Break",
    "Cursor",
    "Recov",
    "Invis",
    "Object",
    "Null"
  ]

  @colors [
    "White",
    "Pink",
    "Yellow",
    "Green",
    "Blue",
    "Red",
    "Gray"
  ]

  def call_slash(%Nostrum.Struct.Interaction{type: 2} = inter) do
    [sub_cmd] = inter.data.options

    case {sub_cmd.name, sub_cmd.options} do
      {"search", [%{value: name}]} ->
        # [opt] = sub_cmd.options
        # name = opt.value
        search_ncp(inter, name)

      {"color", [%{value: color}]} ->
        color = String.to_existing_atom(color)
        ncps = NCP.get_ncps_by_color(color)
        send_ncp_color(inter, color, ncps)

      {"color", [%{value: color}, %{value: cost}]} when is_integer(cost) ->
        color = String.to_existing_atom(color)
        ncps = NCP.get_ncps_by_color(color) |> Enum.filter(fn ncp -> ncp.cost <= cost end)
        send_ncp_color(inter, color, ncps, cost)

      {"starter", [%{value: elem}]} ->
        elem = String.to_existing_atom(elem)
        send_starter_ncps(inter, elem)

      {"starter", _} ->
        send_starter_ncps(inter, :null)
    end

    :ignore
  end

  def call_slash(%Nostrum.Struct.Interaction{type: 4} = inter) do
    [sub_cmd] = inter.data.options

    case sub_cmd.name do
      "search" ->
        [opt] = sub_cmd.options
        name = opt.value
        search_ncp(inter, name)
    end

    :ignore
  end

  def get_create_map do
    color_choices =
      Enum.map(@colors, fn name ->
        %{
          name: name,
          value: String.downcase(name, :ascii)
        }
      end)

    element_choices =
      Enum.map(@elements, fn name ->
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
              required: true,
              autocomplete: true
            }
          ]
        },
        %{
          type: 1,
          name: "starter",
          description: "List all starter programs",
          options: [
            %{
              type: 3,
              name: "element",
              description: "The element to list them for",
              required: false,
              choices: element_choices
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
            },
            %{
              type: 4,
              name: "max_cost",
              description: "The maximum cost of the NCPs to search for",
              required: false,
              min_value: 1
            }
          ]
        }
      ]
    }
  end

  defp search_ncp(%Nostrum.Struct.Interaction{type: 2} = inter, name) do
    Logger.info(["Searching for the following NCP: ", name])

    case NCP.get_ncp(name) do
      {:found, ncp} ->
        send_found_ncp(inter, ncp)

      {:not_found, possibilities} ->
        handle_not_found_ncp(inter, possibilities)
    end
  end

  defp search_ncp(%Nostrum.Struct.Interaction{type: 4} = inter, name) do
    Logger.debug(["Autocomplete searching for the following NCP: ", inspect(name)])

    list =
      NCP.get_autocomplete(name)
      |> Enum.map(fn {_, name} ->
        lower_name = String.downcase(name, :ascii)
        %{name: name, value: lower_name}
      end)

    {:ok} =
      Api.create_interaction_response(inter, %{
        type: 8,
        data: %{
          choices: list
        }
      })
  end

  defp send_ncp_color(inter, color, ncps, cost \\ nil)

  defp send_ncp_color(inter, color, [], cost) do
    Logger.debug(["No NCPs found for color: ", color])

    color_str = to_string(color) |> String.capitalize(:ascii)

    content =
      if is_nil(cost) do
        "There are no #{color_str} NCPs"
      else
        "There are no #{color_str} NCPs with a cost no greater than #{cost} EB"
      end

    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: content,
            flags: 64
          }
        }
      )
  end

  defp send_ncp_color(inter, color, ncps, cost) do
    buttons = BnBBot.ButtonAwait.generate_persistent_buttons(ncps)

    color_str = to_string(color) |> String.capitalize(:ascii)

    content =
      if is_nil(cost) do
        "There are the #{color_str} NCPs"
      else
        "These are the #{color_str} NCPs with a cost no greater than #{cost} EB"
      end

    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: content,
            components: buttons
          }
        }
      )

    # five minutes
    BnBBot.Util.wait_or_shutdown(300_000)

    buttons = BnBBot.ButtonAwait.generate_persistent_buttons(ncps, true)

    route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

    Api.request(:patch, route, %{
      content: content,
      components: buttons
    })
  end

  defp send_starter_ncps(inter, element) do
    Logger.debug(["Sending Starter NCPS for ", to_string(element)])

    starters = NCP.element_to_colors(element) |> NCP.get_starters()

    buttons = BnBBot.ButtonAwait.generate_persistent_buttons(starters)

    elem_str = to_string(element) |> String.capitalize(:ascii)

    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: "These are the starters for #{elem_str}:",
            components: buttons
          }
        }
      )

    # five minutes
    BnBBot.Util.wait_or_shutdown(300_000)

    buttons = BnBBot.ButtonAwait.generate_persistent_buttons(starters, true)

    {:ok, _message} =
      Api.edit_interaction_response(inter, %{
        content: "These are the starters for #{elem_str}:",
        components: buttons
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
