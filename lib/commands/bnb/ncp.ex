defmodule BnBBot.Commands.NCP do
  require Logger

  alias Nostrum.Api

  @behaviour BnBBot.SlashCmdFn

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    [opt] = inter.data.options
    name = opt.value
    Logger.debug(["Searching for the following NCP: ", name])

    case BnBBot.Library.NCP.get_ncp(name) do
      {:found, ncp} ->
        send_found_ncp(inter, ncp)

      {:not_found, possibilities} ->
        handle_not_found_ncp(inter, possibilities)
    end
    :ignore
  end

  def get_create_map() do
    %{
      type: 1,
      name: "ncp",
      description: "Searches for a particular NCP",
      options: [
        %{
          type: 3,
          name: "name",
          description: "The name of the NCP to search for",
          required: true
        }
      ]
    }
  end

  defp send_found_ncp(%Nostrum.Struct.Interaction{} = inter, %BnBBot.Library.NCP{} = ncp) do
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
