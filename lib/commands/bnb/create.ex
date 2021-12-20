defmodule BnBBot.Commands.Create do
  # alias Nostrum.Api
  require Logger

  @behaviour BnBBot.SlashCmdFn

  # TODO

  def call_slash(%Nostrum.Struct.Interaction{} = _inter) do
    raise UndefinedFunctionError
  end

  def get_create_map() do
    %{
      type: 1,
      name: "create",
      description: "Create a new library object",
      options: [
        virus_create_map()
      ]
    }
  end

  defp virus_create_map() do
    %{
      type: 1,
      name: "virus",
      description: "Build the JSON object for adding a virus.",
      options: [
        %{
          type: 3,
          name: "name",
          description: "The name of the virus.",
          required: true
        }
      ]
    }
  end
end
