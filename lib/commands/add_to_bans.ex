defmodule BnBBot.Commands.AddToBans do
  require Logger
  alias Nostrum.Api
  use Ecto.Schema
  import Ecto.Query, only: [from: 2]

  @type t :: %__MODULE__{
          added_by: Nostrum.Snowflake.t(),
          to_ban: Nostrum.Snowflake.t(),
          inserted_at: NaiveDateTime.t()
        }

  schema "banlist" do
    field(:added_by, :integer)
    field(:to_ban, :integer)
    timestamps(updated_at: false)
  end

  def add_to_bans(inter, [%Nostrum.Struct.ApplicationCommandInteractionDataOption{value: to_add}]) do
    if BnBBot.Util.is_owner_msg?(inter) or BnBBot.Util.is_admin_msg?(inter) do
      add_id_to_list(inter, inter.member.user.id, to_add)
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  def salt_the_earth(inter) do
    if BnBBot.Util.is_owner_msg?(inter) or BnBBot.Util.is_admin_msg?(inter) do
      tasks =
        BnBBot.Repo.all(__MODULE__)
        |> Enum.map(fn row ->
          Task.async(Api, :create_guild_ban, [inter.guild_id, row.to_ban, 0, "Salting the Earth"])
        end)

      msg_task =
        Task.async(fn ->
          Api.create_interaction_response(inter, %{
            type: 4,
            data: %{
              content: "DEUS VULT! DEUS VULT! DEUS VULT!"
            }
          })
        end)

      Task.await_many([msg_task | tasks], :infinity)

      route = "/webhooks/#{inter.application_id}/#{inter.token}"

      Api.request(:post, route, %{
        content:
          "A time to love and a time to hate; A time for war and a time for peace. - Ecclesiastes 3:8"
      })
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  defp add_id_to_list(inter, author_id, to_add) do
    author_id = Nostrum.Snowflake.cast!(author_id)
    to_add = Nostrum.Snowflake.cast!(to_add)

    query = from(u in __MODULE__, where: u.to_ban == ^to_add)

    unless BnBBot.Repo.exists?(query) do
      row = %__MODULE__{
        to_ban: to_add,
        added_by: author_id
      }

      BnBBot.Repo.insert!(row)

      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "Added <@#{to_add}> to the banlist",
          flags: 64
        }
      })
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "That user is already on the list",
          flags: 64
        }
      })
    end
  end
end
