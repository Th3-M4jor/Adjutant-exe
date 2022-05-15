defmodule BnBBot.SlashCommands do
  @moduledoc """
  Module for creating and performing dispatch on slash commands
  """

  alias BnBBot.Commands
  alias Nostrum.Api

  require Logger

  @owner_id :elixir_bot |> Application.compile_env!(:owner_id)
  @admins :elixir_bot |> Application.compile_env!(:admins)

  @doc """
  Create all non-privileged slash commands globally
  """
  @spec create_all_slash_commands :: any()
  def create_all_slash_commands do
    body = [
      Commands.Ping.get_create_map(),
      Commands.Dice.get_create_map(),
      Commands.Shuffle.get_create_map(),
      Commands.PHB.get_create_map(),
      Commands.NCP.get_create_map(),
      Commands.Chip.get_create_map(),
      Commands.Virus.get_create_map(),
      Commands.Statuses.get_create_map(),
      Commands.Blight.get_create_map(),
      Commands.Panels.get_create_map(),
      Commands.Groups.get_create_map()
    ]

    Api.bulk_overwrite_global_application_commands(body)
  end

  @doc """
  Create all non-privileged slash commands in a single guild
  """
  @spec create_all_slash_commands(Nostrum.Snowflake.t()) :: any()
  def create_all_slash_commands(guild_id) do
    body = [
      Commands.Ping.get_create_map(),
      Commands.Dice.get_create_map(),
      Commands.Shuffle.get_create_map(),
      Commands.PHB.get_create_map(),
      Commands.NCP.get_create_map(),
      Commands.Chip.get_create_map(),
      Commands.Virus.get_create_map(),
      Commands.Statuses.get_create_map(),
      Commands.Blight.get_create_map(),
      Commands.Panels.get_create_map(),
      Commands.Groups.get_create_map()
    ]

    Api.bulk_overwrite_guild_application_commands(guild_id, body)
  end

  @doc """
  Dispatch functionality on slash commands, including autocomplete, its up the callee to differentiate
  """
  @spec handle_command(Nostrum.Struct.Interaction.t()) :: any
  def handle_command(%Nostrum.Struct.Interaction{} = inter) do
    handle_slash_command(inter.data.name, inter)
  end

  @commands [
    Commands.Dice,
    Commands.Ping,
    Commands.Shuffle,
    Commands.PHB,
    Commands.NCP,
    Commands.Chip,
    Commands.Virus,
    Commands.Statuses,
    Commands.Blight,
    Commands.Panels,
    Commands.Reload,
    Commands.Groups,
    Commands.Hidden,
    Commands.Create,
    Commands.RemindMe
  ]

  # Generate the command handlers at compile time.
  for cmd <- @commands, Code.ensure_compiled!(cmd) do
    name = cmd.get_create_map()[:name]
    true = function_exported?(cmd, :call, 1)
    true = function_exported?(cmd, :call_slash, 1)

    defp handle_slash_command(unquote(name), %Nostrum.Struct.Interaction{} = inter) do
      unquote(cmd).call(inter)
    end
  end

  defp handle_slash_command(name, %Nostrum.Struct.Interaction{} = inter) do
    Logger.warn("slash command #{name} doesn't exist")

    Api.create_interaction_response!(
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
