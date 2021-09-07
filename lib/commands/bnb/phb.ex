defmodule BnBBot.Commands.PHB do
  require Logger

  alias Nostrum.Api

  @behaviour BnBBot.SlashCmdFn

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    link_buttons = Application.fetch_env!(:elixir_bot, :phb_links)
      |> Enum.chunk_every(5)
      |> Enum.map(fn links ->
        %{
          type: 1,
          components: links
        }
      end)

    {:ok} = Api.create_interaction_response(
      inter,
      %{
        type: 4,
        data: %{
          content: "B&B Links:",
          components: link_buttons
        }
      }
    )
    :ignore
  end

  def get_create_map() do
    %{
      type: 1,
      name: "links",
      description: "Get a link to the PHB and Manager"
    }
  end
end
