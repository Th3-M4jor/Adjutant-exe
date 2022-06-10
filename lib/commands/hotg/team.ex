defmodule BnBBot.Commands.Team do
  @moduledoc """
  Command for randomly assigning Ranger characters to players in a team.
  """

  alias Nostrum.Api
  require Logger

  use BnBBot.SlashCmdFn, permissions: :everyone

  @impl true
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Received a HOTG slash command")

    file = File.read!("hotg_assets.json") |> Jason.decode!()

    %{"rangers" => ranger_list, "minions" => minion_list, "monsters" => monster_list, "bosses" => boss_list} = file

    players = Enum.take_random(ranger_list, 6) |> Enum.intersperse(", ")
    minions = Enum.take_random(minion_list, 2) |> Enum.intersperse(", ")
    monsters = Enum.take_random(monster_list, 2) |> Enum.intersperse(", ")
    boss = Enum.random(boss_list)

    resp_str = ["Rangers: ", players, "\n", "Minions: ", minions, "\n", "Monsters: ", monsters, "\n", "Boss: ", boss] |> IO.iodata_to_binary()

    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: resp_str
        }
      }
    )

  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "morphin",
      description: "Creates a random HOTG game for you."
    }
  end
end
