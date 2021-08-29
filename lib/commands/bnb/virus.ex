defmodule BnBBot.Commands.Virus do
  alias Nostrum.Api
  alias BnBBot.Library.Virus
  require Logger

  @behaviour BnBBot.SlashCmdFn

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    [sub_cmd] = inter.data.options

    case sub_cmd.name do
      "search" ->
        [opt] = sub_cmd.options
        name = opt.value
        search_virus(inter, name)

      "cr" ->
        [opt] = sub_cmd.options
        cr = opt.value
        cr_list = Virus.get_cr_list(cr)
        send_cr_list(inter, cr, cr_list)
    end
  end

  def get_create_map() do
    %{
      type: 1,
      name: "virus",
      description: "The virus group",
      options: [
        %{
          type: 1,
          name: "search",
          description: "Search for a particular virus",
          options: [
            %{
              type: 3,
              name: "name",
              description: "The name of the virus to search for",
              required: true
            }
          ]
        },
        %{
          type: 1,
          name: "cr",
          description: "get all viruses in a particular CR",
          options: [
            %{
              type: 4,
              name: "cr",
              description: "The CR to search for",
              required: true
            }
          ]
        }
      ]
    }
  end

  defp search_virus(inter, name) do
    Logger.debug(["Searching for the following virus: ", name])

    case Virus.get_virus(name) do
      {:found, virus} ->
        Logger.debug(["Found the following virus: ", virus.name])
        send_found_virus(inter, virus)

      {:not_found, possibilities} ->
        handle_not_found(inter, possibilities)
    end
  end

  defp send_cr_list(inter, cr, []) do
    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: "There are no viruses in CR #{cr}",
            flags: 64
          }
        }
      )
  end

  defp send_cr_list(inter, cr, cr_list) do
    buttons = BnBBot.ButtonAwait.generate_persistent_buttons(cr_list)

    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: "These viruses are in CR #{cr}:",
            components: buttons
          }
        }
      )

    Process.sleep(300000) # five minutes
    names = Enum.map(cr_list, fn virus ->
      virus.name
    end) |> Enum.join(", ")

    route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

    Api.request(:patch, route, %{
      content: "These viruses are in CR #{cr}:\n#{names}",
      components: []
    })

  end

  def send_found_virus(%Nostrum.Struct.Interaction{} = inter, virus) do
    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: to_string(virus)
          }
        }
      )
  end

  defp handle_not_found(inter, opts) do
    Logger.debug("No virus found, showing suggestions")

    BnBBot.Commands.All.do_btn_response(inter, opts)
  end
end
