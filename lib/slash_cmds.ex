defmodule BnBBot.SlashCommands do
  # alias Nostrum.Api
  alias BnBBot.Commands
  alias Nostrum.Api

  require Logger

  @spec create_all_slash_commands :: any()
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
      Commands.Virus.get_create_map(),
      Commands.All.get_create_map(),
      Commands.Statuses.get_create_map(),
      Commands.Blight.get_create_map(),
      Commands.Panels.get_create_map()
    ]

    Api.request(:put, route, body)
  end

  @spec create_all_slash_commands(Nostrum.Snowflake.t()) :: any()
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
      Commands.Virus.get_create_map(),
      Commands.All.get_create_map(),
      Commands.Statuses.get_create_map(),
      Commands.Blight.get_create_map(),
      Commands.Panels.get_create_map()
    ]

    Api.request(:put, route, body)
  end

  def create_locked_commands(guild_id) do
    me_id = Nostrum.Cache.Me.get().id

    reload_cmd = Commands.Reload.get_create_map()

    {:ok, cmd} = Api.create_guild_application_command(guild_id, reload_cmd)

    route = "/applications/#{me_id}/guilds/#{guild_id}/commands/#{cmd.id}/permissions"

    perms =
      [
        Application.fetch_env!(:elixir_bot, :owner_id)
        | Application.fetch_env!(:elixir_bot, :admins)
      ]
      |> Enum.map(fn id ->
        %{
          id: "#{id}",
          type: 2,
          permission: true
        }
      end)

    Api.request(:put, route, %{
      permissions: perms
    })
  end

  @spec handle_command(Nostrum.Struct.Interaction.t()) :: any
  def handle_command(%Nostrum.Struct.Interaction{} = inter) do
    handle_slash_command(inter.data.name, inter)
  end

  @spec handle_slash_command(String.t(), Nostrum.Struct.Interaction.t()) :: :ignore
  defp handle_slash_command("ping", inter) do
    Commands.Ping.call_slash(inter)
  end

  defp handle_slash_command("roll", inter) do
    Commands.Dice.call_slash(inter)
  end

  defp handle_slash_command("shuffle", inter) do
    Commands.Shuffle.call_slash(inter)
  end

  defp handle_slash_command("phb", inter) do
    Commands.PHB.call_slash(inter)
  end

  defp handle_slash_command("ncp", inter) do
    Commands.NCP.call_slash(inter)
  end

  defp handle_slash_command("chip", inter) do
    Commands.Chip.call_slash(inter)
  end

  defp handle_slash_command("virus", inter) do
    Commands.Virus.call_slash(inter)
  end

  defp handle_slash_command("search", inter) do
    Commands.All.call_slash(inter)
  end

  defp handle_slash_command("status", inter) do
    Commands.Statuses.call_slash(inter)
  end

  defp handle_slash_command("blight", inter) do
    Commands.Blight.call_slash(inter)
  end

  defp handle_slash_command("panel", inter) do
    Commands.Panels.call_slash(inter)
  end

  defp handle_slash_command("reload", inter) do
    Commands.Reload.call_slash(inter)
  end

  defp handle_slash_command(name, inter) do
    Logger.warn("slash command #{name} doesn't exist")

    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: "Woops, Major forgot to implement this command",
            flags: 64
          }
        }
      )
  end
end
