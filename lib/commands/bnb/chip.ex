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

      "cr" ->
        [opt] = sub_cmd.options
        cr = opt.value
        cr_list = BnBBot.Library.Battlechip.get_cr(cr)
        send_cr_list(inter, cr, cr_list)

      "skill-cr" ->
        [cr, skill] = sub_cmd.options
        cr = cr.value
        skill = skill.value |> BnBBot.Library.Shared.skill_to_atom()
        chips = BnBBot.Library.Battlechip.get_skill_cr(skill, cr)
        send_skill_cr_list(inter, skill, cr, chips)
    end

    :ignore
  end

  def call_slash(%Nostrum.Struct.Interaction{type: 4} = inter) do
    [sub_cmd] = inter.data.options
    [opt] = sub_cmd.options
    name = opt.value

    search_chip(inter, name)
  end

  @impl true
  def get_create_map do
    skill_choices =
      Enum.map(@skills, fn skill ->
        %{
          name: skill,
          value: String.downcase(skill, :ascii)
        }
      end)

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
        %{
          type: 1,
          name: "skill-cr",
          description: "List all chips with a particular CR and skill",
          options: [
            %{
              type: 4,
              name: "cr",
              description: "The CR of the chip",
              required: true,
              min_value: 1,
              max_value: 20
            },
            %{
              type: 3,
              name: "skill",
              description: "The skill of the chip",
              required: true,
              choices: skill_choices
            }
          ]
        },
        %{
          type: 1,
          name: "cr",
          description: "List all chips in a certain CR",
          options: [
            %{
              type: 4,
              name: "cr",
              description: "The CR to search for",
              required: true,
              min_value: 1,
              max_value: 20
            }
          ]
        }
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

  defp send_cr_list(inter, cr, []) do
    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: "There are no chips in CR #{cr} at present",
            flags: 64
          }
        }
      )
  end

  defp send_cr_list(inter, cr, cr_list) do
    cr_list =
      Enum.sort_by(cr_list, fn chip ->
        chip.id
      end)

    buttons = BnBBot.ButtonAwait.generate_persistent_buttons(cr_list)

    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: "These chips are in CR #{cr}:",
            components: buttons
          }
        }
      )

    route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

    # five minutes
    BnBBot.Util.wait_or_shutdown(300_000)

    buttons = BnBBot.ButtonAwait.generate_persistent_buttons(cr_list, true)

    Api.request(:patch, route, %{
      content: "These chips are in CR #{cr}:",
      components: buttons
    })
  end

  defp send_skill_cr_list(inter, skill, cr, []) do
    str =
      if is_nil(skill) do
        "There are no chips in CR #{cr} that do not have a skill"
      else
        skill = BnBBot.Library.Shared.skill_to_string(skill)
        "There are no chips in CR #{cr} that use #{skill}"
      end

    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: str,
            flags: 64
          }
        }
      )
  end

  defp send_skill_cr_list(inter, skill, cr, cr_list) do
    cr_list =
      Enum.sort_by(cr_list, fn chip ->
        chip.id
      end)

    buttons = BnBBot.ButtonAwait.generate_persistent_buttons(cr_list)

    msg =
      if is_nil(skill) do
        "These chips are in CR #{cr} that do not have a skill:"
      else
        skill = BnBBot.Library.Shared.skill_to_string(skill)
        "These chips are in CR #{cr} that use #{skill}:"
      end

    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: msg,
            components: buttons
          }
        }
      )

    route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

    # five minutes
    BnBBot.Util.wait_or_shutdown(300_000)

    buttons = BnBBot.ButtonAwait.generate_persistent_buttons(cr_list, true)

    Api.request(:patch, route, %{
      content: msg,
      components: buttons
    })
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
end
