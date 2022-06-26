defmodule BnBBot.OneOffs.RecreateCommands do
  @moduledoc """
  One-off script for getting all commands
  re-inserted and into the state database
  """

  alias BnBBot.Command.State, as: CreationState

  alias Nostrum.Api

  @slash_commands [
    BnBBot.Command.Slash.Dice,
    BnBBot.Command.Slash.Ping,
    BnBBot.Command.Slash.Shuffle,
    BnBBot.Command.Slash.BNB.PHB,
    BnBBot.Command.Slash.BNB.NCP,
    BnBBot.Command.Slash.BNB.Chip,
    BnBBot.Command.Slash.BNB.Virus,
    BnBBot.Command.Slash.BNB.Status,
    BnBBot.Command.Slash.BNB.Blight,
    BnBBot.Command.Slash.BNB.Panels,
    BnBBot.Command.Slash.BNB.Reload,
    BnBBot.Command.Slash.BNB.Groups,
    BnBBot.Command.Slash.Hidden,
    BnBBot.Command.Slash.BNB.Create,
    BnBBot.Command.Slash.RemindMe,
    BnBBot.Command.Slash.HOTG.Team
  ]

  def execute do
    BnBBot.Repo.SQLite.transaction(fn ->
      insert_global_commands()
      insert_guild_commands()
    end)
  end

  defp insert_global_commands do
    global_cmds = get_global_commands_list()

    unless Enum.empty?(global_cmds) do
      to_create =
        Enum.map(global_cmds, fn {_, cmd_map} ->
          cmd_map
        end)

      {:ok, cmds} = Api.bulk_overwrite_global_application_commands(to_create)
      cmds = Enum.sort_by(cmds, fn cmd -> cmd.name end)
      global_cmds = Enum.sort_by(global_cmds, fn {_, cmd} -> cmd.name end)

      Enum.zip(cmds, global_cmds)
      |> Enum.each(fn {%{id: id}, {_, cmd_map} = to_ins} ->
        name = cmd_map.name
        state = :erlang.term_to_binary(to_ins)
        id = Nostrum.Snowflake.cast!(id)
        state = %CreationState{name: name, state: state, cmd_ids: {:global, id}}
        BnBBot.Repo.SQLite.insert!(state, on_conflict: {:replace, [:state, :cmd_ids]})
      end)
    end
  end

  defp get_global_commands_list do
    Enum.map(@slash_commands, fn cmd ->
      cmd.get_creation_state()
    end)
    |> Enum.filter(fn {scope, _cmd_map} ->
      scope == :global
    end)
  end

  defp insert_guild_commands do
    guild_commands = get_guild_commands_list()

    unless Enum.empty?(guild_commands) do
      cmd_map = guild_command_list_to_map(guild_commands)

      name_id_list =
        Enum.map(cmd_map, &bulk_insert_guild_commands/1)
        |> :lists.append()

      name_to_id_map =
        :maps.groups_from_list(
          fn {name, _guild_id, _id} ->
            name
          end,
          fn {_name, guild_id, id} ->
            {guild_id, id}
          end,
          name_id_list
        )

      Enum.each(guild_commands, fn {_, cmd_map} = to_ins ->
        name = cmd_map.name
        state = :erlang.term_to_binary(to_ins)
        state = %CreationState{name: name, state: state, cmd_ids: {:guild, name_to_id_map[name]}}
        BnBBot.Repo.SQLite.insert!(state, on_conflict: {:replace, [:state, :cmd_ids]})
      end)
    end
  end

  defp bulk_insert_guild_commands({guild_id, cmd_list}) do
    {:ok, cmds} = Api.bulk_overwrite_guild_application_commands(guild_id, cmd_list)

    Enum.map(cmds, fn cmd ->
      cmd_id = Nostrum.Snowflake.cast!(cmd.id)
      {cmd.name, guild_id, cmd_id}
    end)
  end

  defp get_guild_commands_list do
    Enum.map(@slash_commands, fn cmd ->
      cmd.get_creation_state()
    end)
    |> Enum.reject(fn {scope, _cmd_map} ->
      scope == :global
    end)
  end

  defp guild_command_list_to_map(guild_commands) do
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
