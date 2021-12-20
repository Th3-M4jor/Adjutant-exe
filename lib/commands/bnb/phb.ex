defmodule BnBBot.Commands.PHB do
  require Logger

  alias Nostrum.Api

  @phb_links :elixir_bot |> Application.compile_env!(:phb_links)

  @behaviour BnBBot.SlashCmdFn

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a links command")

    link_buttons =
      @phb_links
      |> Enum.chunk_every(5)
      |> Enum.map(fn links ->
        %{
          type: 1,
          components: links
        }
      end)

    {:ok} =
      Api.create_interaction_response(
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
