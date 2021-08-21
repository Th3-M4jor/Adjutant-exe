defmodule BnBBot.Commands.PHB do
  require Logger

  alias Nostrum.Api

  @behaviour BnBBot.SlashCmdFn

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    phb_url = Application.fetch_env!(:elixir_bot, :phb)

    Api.create_interaction_response(
      inter,
      %{
        type: 4,
        data: %{
          content: "B&B Players Handbook Links:",
          components: [
            %{
              type: 1,
              components: [
                %{
                  type: 2,
                  style: 5,
                  label: "B&B PHB",
                  url: phb_url
                }
              ]
            }
          ]
        }
      }
    )
    :ignore
  end

  def get_create_map() do
    %{
      type: 1,
      name: "phb",
      description: "Get a link to the PHB"
    }
  end
end
