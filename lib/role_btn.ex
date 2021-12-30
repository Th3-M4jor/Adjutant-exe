defmodule BnBBot.RoleBtn do
  @moduledoc """
  This module is used to handle the role button clicks.
  """
  require Logger
  alias Nostrum.Api

  @roles :elixir_bot |> Application.compile_env!(:roles)

  def generate_role_btns() do
    @roles
    |> Enum.chunk_every(5)
    |> Enum.map(fn row ->
      action_row =
        Enum.map(row, fn role ->
          %{
            type: 2,
            style: role.style,
            emoji: role[:emoji],
            label: role.name,
            custom_id: "r_#{role.id}"
          }
        end)

      %{
        type: 1,
        components: action_row
      }
    end)
  end

  @spec send_role_btns(Nostrum.Snowflake.t(), String.t()) :: :ignore
  def send_role_btns(channel_id, msg) do
    buttons = generate_role_btns()
    Api.create_message!(channel_id, content: msg, components: buttons)

    :ignore
  end

  def handle_role_btn_click(%Nostrum.Struct.Interaction{} = inter, id) do
    id = Nostrum.Snowflake.cast!(id)

    add_or_remove =
      unless Enum.member?(inter.member.roles, id) do
        {:ok} =
          Api.add_guild_member_role(inter.guild_id, inter.member.user.id, id, "Button Click")

        "added"
      else
        {:ok} =
          Api.remove_guild_member_role(inter.guild_id, inter.member.user.id, id, "Button Click")

        "removed"
      end

    {:ok} =
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "Role has been #{add_or_remove}",
          flags: 64
        }
      })
  end
end
