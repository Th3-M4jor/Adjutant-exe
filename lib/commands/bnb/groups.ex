defmodule BnBBot.Commands.Groups do
  @moduledoc """
  This module contains commands for getting information about folder groups.

  `group_force_closed/1` is called by a remote node when it force closes a group.
  """

  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  require Logger

  @backend_node_name :elixir_bot |> Application.compile_env!(:backend_node_name)
  @dm_log_id :elixir_bot |> Application.compile_env!(:dm_log_id)

  @behaviour BnBBot.SlashCmdFn

  @spec call_slash(Nostrum.Struct.Interaction.t()) :: :ignore
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a groups command")

    if Node.alive?() and Node.connect(@backend_node_name) do
      fetch_and_send_groups(inter, @backend_node_name)
    else
      node_down(inter)
    end
  end

  def get_create_map() do
    %{
      type: 1,
      name: "groups",
      description: "Get a list of active folder groups in the manager"
    }
  end

  @spec group_force_closed(String.t()) :: :ignore
  def group_force_closed(group_name) do
    dm_channel_id =
      @dm_log_id
      |> Nostrum.Snowflake.cast!()

    Nostrum.Api.create_message(dm_channel_id, "Group #{group_name} has been force closed")
    :ignore
  end

  @spec fetch_and_send_groups(Nostrum.Struct.Interaction.t(), node()) :: :ignore
  defp fetch_and_send_groups(%Nostrum.Struct.Interaction{} = inter, backend_name) do
    embed =
      :erpc.call(backend_name, ElixirBackend.FolderGroups, :get_groups_and_ct, [])
      |> groups_to_embed()

    {:ok} =
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          embeds: [embed]
        }
      })

    :ignore
  end

  @spec groups_to_embed([{String.t(), %{count: non_neg_integer(), spectators: non_neg_integer()}}]) ::
          Embed.t()
  defp groups_to_embed([]) do
    %Embed{
      title: "Groups",
      description: "No groups found",
      color: 0xFF0000,
      fields: []
    }
  end

  defp groups_to_embed(groups) do
    fields =
      Enum.take(groups, 25)
      |> Enum.map(fn {name, %{count: total_players, spectators: spectators}} ->
        %Embed.Field{
          name: name,
          value: "Players: #{total_players - spectators} | Spectators: #{spectators}",
          inline: true
        }
      end)

    %Embed{
      title: "Groups",
      color: 0x21ADE9,
      fields: fields
    }
  end

  @spec node_down(Nostrum.Struct.Interaction.t()) :: :ignore
  defp node_down(%Nostrum.Struct.Interaction{} = inter) do
    {:ok} =
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "The backend is currently down, please inform Major",
          flags: 64
        }
      })

    :ignore
  end
end
