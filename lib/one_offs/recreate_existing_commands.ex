defmodule BnBBot.OneOffs.RecreateCommands do
  @moduledoc """
  One-off script for getting all commands
  re-inserted and into the state database
  """

  alias BnBBot.Commands
  alias BnBBot.SlashCommands.CreationState

  alias Nostrum.Api

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
    Commands.RemindMe,
    Commands.Team
  ]

  def execute do
    BnBBot.Repo.SQLite.transaction(fn ->
      insert_global_commands()
      insert_guild_commands()
    end)
  end

  def insert_global_commands do
    global_cmds = get_global_commands_list()

    unless Enum.empty?(global_cmds) do
      to_create =
        Enum.map(global_cmds, fn {_, cmd_map} ->
          cmd_map
        end)

      Api.bulk_overwrite_global_application_commands(to_create)

      Enum.each(global_cmds, fn {_, cmd_map} = to_ins ->
        name = cmd_map.name
        state = :erlang.term_to_binary(to_ins)
        state = %CreationState{name: name, state: state}
        BnBBot.Repo.SQLite.insert!(state)
      end)
    end
  end

  def get_global_commands_list do
    Enum.map(@commands, fn cmd ->
      cmd.get_creation_state()
    end)
    |> Enum.filter(fn {scope, _cmd_map} ->
      scope == :global
    end)
  end

  def insert_guild_commands do
    guild_commands = get_guild_commands_list()

    unless Enum.empty?(guild_commands) do
      cmd_map = guild_command_list_to_map(guild_commands)

      Enum.each(cmd_map, fn {guild_id, cmd_list} ->
        Api.bulk_overwrite_guild_application_commands(guild_id, cmd_list)
      end)

      Enum.each(guild_commands, fn {_, cmd_map} = to_ins ->
        name = cmd_map.name
        state = :erlang.term_to_binary(to_ins)
        state = %CreationState{name: name, state: state}
        BnBBot.Repo.SQLite.insert!(state)
      end)
    end
  end

  def get_guild_commands_list do
    Enum.map(@commands, fn cmd ->
      cmd.get_creation_state()
    end)
    |> Enum.reject(fn {scope, _cmd_map} ->
      scope == :global
    end)
  end

  def guild_command_list_to_map(guild_commands) do
    Enum.reduce(guild_commands, %{}, fn {scope, cmd_map}, map ->
      if is_list(scope) do
        Enum.reduce(scope, map, fn guild_id, acc ->
          Map.update(acc, guild_id, [cmd_map], fn existing_value -> [cmd_map | existing_value] end)
        end)
      else
        # Scope is a single guild
        Map.update(map, scope, [cmd_map], fn existing_value -> [cmd_map | existing_value] end)
      end
    end)
  end
end
