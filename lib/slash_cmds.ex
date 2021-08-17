defmodule BnBBot.SlashCommands do
  # alias Nostrum.Api
  alias BnBBot.Commands
  alias Nostrum.Api

  require Logger

  def create_all_slash_commands() do
    me_id = Nostrum.Cache.Me.get().id
    route = "/applications/#{me_id}/commands"

    body = [
      Commands.Ping.get_create_map(),
      Commands.Dice.get_create_map(),
      Commands.Shuffle.get_create_map(),
      Commands.PHB.get_create_map(),
      Commands.NCP.get_create_map(),
      Commands.Chip.get_create_map(),
      Commands.All.get_create_map()
    ]

    Api.request(:put, route, body)
  end

  @spec create_all_slash_commands(Nostrum.Snowflake.t()) :: any
  def create_all_slash_commands(guild_id) do
    me_id = Nostrum.Cache.Me.get().id
    route = "/applications/#{me_id}/guilds/#{guild_id}/commands"

    body = [
      Commands.Ping.get_create_map(),
      Commands.Dice.get_create_map(),
      Commands.Shuffle.get_create_map(),
      Commands.PHB.get_create_map(),
      Commands.NCP.get_create_map(),
      Commands.Chip.get_create_map(),
      Commands.All.get_create_map()
    ]

    Api.request(:put, route, body)
  end

  @spec handle_command(Nostrum.Struct.Interaction.t()) :: any
  def handle_command(%Nostrum.Struct.Interaction{} = inter) do
    name = inter.data.name
    handle_slash_command(name, inter)
  end

  defp handle_slash_command("ping", %Nostrum.Struct.Interaction{} = inter) do
    Commands.Ping.call_slash(inter)
  end

  defp handle_slash_command("roll", %Nostrum.Struct.Interaction{} = inter) do
    Commands.Dice.call_slash(inter)
  end

  defp handle_slash_command("shuffle", %Nostrum.Struct.Interaction{} = inter) do
    Commands.Shuffle.call_slash(inter)
  end

  defp handle_slash_command("phb", %Nostrum.Struct.Interaction{} = inter) do
    Commands.PHB.call_slash(inter)
  end

  defp handle_slash_command("ncp", %Nostrum.Struct.Interaction{} = inter) do
    Commands.NCP.call_slash(inter)
  end

  defp handle_slash_command("chip", %Nostrum.Struct.Interaction{} = inter) do
    Commands.Chip.call_slash(inter)
  end

  defp handle_slash_command("search", %Nostrum.Struct.Interaction{} = inter) do
    Commands.All.call_slash(inter)
  end

  defp handle_slash_command(name, %Nostrum.Struct.Interaction{} = inter) do
    Logger.warn("slash command #{name} doesn't exist")

    Api.create_interaction_response(
      inter,
      %{
        type: 4,
        data: %{
          content: "Woops, Major forgot to implement this slash command",
          flags: 64
        }
      }
    )
  end
end
