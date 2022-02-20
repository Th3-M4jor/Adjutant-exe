defmodule BnBBot.Commands.Chip do
  @moduledoc """
  Contains all BattleChip related commands.

  Currently there are:

  `search` - Searches for a BattleChip

  `dropped-by` - Lists all viruses which drop that particular chip
  """

  alias Nostrum.Api
  require Logger

  use BnBBot.SlashCmdFn, permissions: :everyone
  @skills ~w(PER INF TCH STR AGI END CHM VLR AFF None)
  @elements ~w(Fire Aqua Elec Wood Wind Sword Break Cursor Recov Invis Object Null)
  @chip_kinds ~w(Burst Construct Melee Projectile Wave Heal Summon Trap)

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{type: 2} = inter) do
    [sub_cmd] = inter.data.options

    case sub_cmd.name do
      "search" ->
        [opt] = sub_cmd.options
        name = opt.value
        search_chip(inter, name)

      "dropped-by" ->
        [opt] = sub_cmd.options
        name = opt.value
        locate_drops(inter, name)

      "filter" ->
        filter_chip_list(inter, sub_cmd.options)
    end

    :ignore
  end

  def call_slash(%Nostrum.Struct.Interaction{type: 4} = inter) do
    [sub_cmd] = inter.data.options
    [opt] = sub_cmd.options
    name = opt.value

    search_chip(inter, name)
  end

  defp filter_chip_cmd_map do
    skill_choices =
      Enum.map(@skills, fn skill ->
        %{
          name: skill,
          value: String.downcase(skill, :ascii)
        }
      end)

    element_choices =
      Enum.map(@elements, fn element ->
        %{
          name: element,
          value: String.downcase(element, :ascii)
        }
      end)

    chip_kind_choices =
      Enum.map(@chip_kinds, fn chip_kind ->
        %{
          name: chip_kind,
          value: String.downcase(chip_kind, :ascii)
        }
      end)

    %{
      type: 1,
      name: "filter",
      description: "Filter the chip list, errors if more than 25 chips would be returned",
      options: [
        %{
          type: 3,
          name: "skill",
          description: "The skill the chip uses",
          choices: skill_choices
        },
        %{
          type: 3,
          name: "element",
          description: "The element the chip uses",
          choices: element_choices
        },
        %{
          type: 4,
          name: "cr",
          description: "The CR of the chip",
          min_value: 0,
          max_value: 20
        },
        %{
          type: 3,
          name: "blight",
          description: "The blight the chip causes, use null for none",
          choices: element_choices
        },
        %{
          type: 3,
          name: "kind",
          description: "The kind of attack the chip is",
          choices: chip_kind_choices
        },
        %{
          type: 4,
          name: "min_cr",
          description: "The minimum CR of the chip",
          min_value: 1,
          max_value: 20
        },
        %{
          type: 4,
          name: "max_cr",
          description: "The maximum CR of the chip",
          min_value: 1,
          max_value: 20
        },
        %{
          type: 4,
          name: "min_avg_dmg",
          description: "The minimum average damage of the chip",
          min_value: 0
        },
        %{
          type: 4,
          name: "max_avg_dmg",
          description: "The maximum average damage of the chip",
          min_value: 1
        }
      ]
    }
  end

  @impl true
  def get_create_map do
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
              required: true,
              autocomplete: true
            }
          ]
        },
        %{
          type: 1,
          name: "dropped-by",
          description: "List all viruses that drop a particular chip",
          options: [
            %{
              type: 3,
              name: "chip-name",
              description: "The name of the chip",
              required: true,
              autocomplete: true
            }
          ]
        },
        filter_chip_cmd_map()
      ]
    }
  end

  def search_chip(%Nostrum.Struct.Interaction{type: 2} = inter, name) do
    Logger.info(["Searching for the following chip: ", name])

    case BnBBot.Library.Battlechip.get_chip(name) do
      {:found, chip} ->
        Logger.debug(["Found the following chip: ", chip.name])
        send_found_chip(inter, chip)

      {:not_found, possibilities} ->
        handle_not_found(inter, possibilities)
    end
  end

  def search_chip(%Nostrum.Struct.Interaction{type: 4} = inter, name) do
    Logger.debug(["Autocomplete Searching for the following chip: ", inspect(name)])

    list =
      BnBBot.Library.Battlechip.get_autocomplete(name)
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

  def locate_drops(%Nostrum.Struct.Interaction{} = inter, name) do
    Logger.info(["Locating drops for the following chip: ", name])

    case BnBBot.Library.Battlechip.get_chip(name) do
      {:found, chip} ->
        send_drops(inter, chip)

      {:not_found, possibilities} ->
        handle_chip_not_found(inter, possibilities)
    end
  end

  def send_drops(%Nostrum.Struct.Interaction{} = inter, %BnBBot.Library.Battlechip{} = chip) do
    drops = BnBBot.Library.Virus.locate_by_drop(chip)

    if Enum.empty?(drops) do
      {:ok} =
        Api.create_interaction_response(
          inter,
          %{
            type: 4,
            data: %{
              content: "No viruses drop #{chip.name}."
            }
          }
        )
    else
      buttons = BnBBot.ButtonAwait.generate_persistent_buttons(drops)

      {:ok} =
        Api.create_interaction_response(
          inter,
          %{
            type: 4,
            data: %{
              content: "The following viruses drop #{chip.name}:",
              components: buttons
            }
          }
        )

      route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

      buttons = BnBBot.ButtonAwait.generate_persistent_buttons(drops, true)

      # five minutes
      BnBBot.Util.wait_or_shutdown(300_000)

      Api.request(:patch, route, %{
        content: "The following viruses drop #{chip.name}:",
        components: buttons
      })
    end
  end

  def send_drops_found(%Nostrum.Struct.Interaction{} = inter, %BnBBot.Library.Battlechip{} = chip) do
    drops = BnBBot.Library.Virus.locate_by_drop(chip)

    route = "/webhooks/#{inter.application_id}/#{inter.token}"

    if Enum.empty?(drops) do
      {:ok, _resp} =
        Api.request(:post, route, %{
          content: "No known viruses drop #{chip.name}."
        })
    else
      buttons = BnBBot.ButtonAwait.generate_persistent_buttons(drops)

      {:ok, resp} =
        Api.request(:post, route, %{
          content: "The following viruses drop #{chip.name}:",
          components: buttons
        })

      resp = Jason.decode!(resp)

      edit_route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/#{resp["id"]}"

      names =
        Enum.map_join(drops, ", ", fn virus ->
          virus.name
        end)

      # five minutes
      BnBBot.Util.wait_or_shutdown(300_000)

      Api.request(:patch, edit_route, %{
        content: "The following viruses drop #{chip.name}:\n#{names}",
        components: []
      })
    end
  end

  defp handle_chip_not_found(%Nostrum.Struct.Interaction{} = inter, []) do
    {:ok} =
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "I'm sorry, I couldn't find anything with a similar enough name",
          flags: 64
        }
      })

    :ignore
  end

  defp handle_chip_not_found(%Nostrum.Struct.Interaction{} = inter, [{_, chip}]) do
    send_drops(inter, chip)
  end

  defp handle_chip_not_found(%Nostrum.Struct.Interaction{} = inter, possibilities) do
    obj_list = Enum.map(possibilities, fn {_, opt} -> opt end)

    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

    buttons = BnBBot.ButtonAwait.generate_msg_buttons_with_uuid(obj_list, uuid)

    {:ok} =
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

    if is_nil(btn_response) do
      Api.request(:patch, route, %{
        content: "Timed out waiting for response",
        components: []
      })
    else
      {_, {?c, name}} = btn_response
      chip = BnBBot.Library.Battlechip.get!(name)

      Task.start(fn ->
        Api.request(:patch, route, %{
          content: "You selected #{chip.name}",
          components: []
        })
      end)

      send_drops_found(inter, chip)
    end
  end

  defp handle_not_found(inter, opts) do
    Logger.debug("No chip found, showing suggestions")

    BnBBot.Commands.All.do_btn_response(inter, opts)
  end

  defp filter_chip_list(inter, []) do
    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: "You must specify at least one argument",
          flags: 64
        }
      }
    )
  end

  defp filter_chip_list(inter, options) do
    filters = Enum.map(options, &filter_arg_to_tuple/1)

    with :ok <- validate_cr_args(filters),
         :ok <- validate_dmg_args(filters),
         chips when length(chips) in 1..25 <- BnBBot.Library.Battlechip.run_chip_filter(filters) do
      buttons = BnBBot.ButtonAwait.generate_persistent_buttons(chips)

      Api.create_interaction_response!(
        inter,
        %{
          type: 4,
          data: %{
            content: "found these chips:",
            components: buttons
          }
        }
      )

      # five minutes
      BnBBot.Util.wait_or_shutdown(300_000)
      buttons = BnBBot.ButtonAwait.generate_persistent_buttons(chips, true)

      Api.edit_interaction_response!(
        inter,
        %{
          content: "found these chips:",
          components: buttons
        }
      )
    else
      [] ->
        Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content: "No chips found",
              flags: 64
            }
          }
        )

      {:error, msg} ->
        Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content: msg,
              flags: 64
            }
          }
        )

      _ ->
        Api.create_interaction_response!(
          inter,
          %{
            type: 4,
            data: %{
              content: "This returned too many chips, I can't send more than 25 at a time",
              flags: 64
            }
          }
        )
    end
  end

  defp filter_arg_to_tuple(arg) do
    case arg.name do
      "skill" ->
        skill = BnBBot.Library.Shared.skill_to_atom(arg.value)
        {:skill, skill}

      "element" ->
        element = arg.value |> String.downcase(:ascii) |> String.to_existing_atom()
        {:element, element}

      "cr" ->
        {:cr, arg.value}

      "kind" ->
        kind = arg.value |> String.downcase(:ascii) |> String.to_existing_atom()
        {:kind, kind}

      "min_cr" ->
        {:min_cr, arg.value}

      "max_cr" ->
        {:max_cr, arg.value}

      "blight" ->
        element = arg.value |> String.downcase(:ascii) |> String.to_existing_atom()
        {:blight, element}

      "min_avg_dmg" ->
        {:min_avg_dmg, arg.value}

      "max_avg_dmg" ->
        {:max_avg_dmg, arg.value}
    end
  end

  defp validate_cr_args(args) do
    case {args[:min_cr], args[:max_cr], args[:cr]} do
      {nil, nil, nil} ->
        :ok

      {nil, _, nil} ->
        :ok

      {_, nil, nil} ->
        :ok

      {nil, nil, _} ->
        :ok

      {min, max, nil} when min > max ->
        {:error, "`min_cr` must be less than `max_cr`"}

      {min, max, nil} when min == max ->
        {:error, "`min_cr` and `max_cr` are equal, juse use `cr`"}

      {_, _, cr} when not is_nil(cr) ->
        {:error, "`cr` cannot be used with `min_cr` or `max_cr`"}

      _ ->
        :ok
    end
  end

  defp validate_dmg_args(args) do
    case {args[:min_avg_dmg], args[:max_avg_dmg]} do
      {nil, nil} ->
        :ok

      {nil, _} ->
        :ok

      {_, nil} ->
        :ok

      {min, max} when min > max ->
        {:error, "min_avg_dmg must be less than max_avg_dmg"}

      _ ->
        :ok
    end
  end
end
