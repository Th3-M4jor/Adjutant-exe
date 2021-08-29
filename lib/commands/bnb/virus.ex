defmodule BnBBot.Commands.Virus do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.SlashCmdFn

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    [opt] = inter.data.options
    name = opt.value
    Logger.debug(["Searching for the following virus: ", name])

    case BnBBot.Library.Virus.get_virus(name) do
      {:found, virus} ->
        Logger.debug(["Found the following virus: ", virus.name])
        send_found_virus(inter, virus)

      {:not_found, possibilities} ->
        handle_not_found(inter, possibilities)
    end
  end

  def get_create_map() do
    %{
      type: 1,
      name: "virus",
      description: "Search for a virus with the given name, returns full data on it",
      options: [
        %{
          type: 3,
          name: "name",
          description: "The name of the virus to search for",
          required: true,
        }
      ]
    }
  end

  def send_found_virus(%Nostrum.Struct.Interaction{} = inter, virus) do
    {:ok} = Api.create_interaction_response(
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
