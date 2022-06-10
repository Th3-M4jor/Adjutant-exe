defmodule BnBBot.Commands.Team do
  @moduledoc """
  Command for randomly assigning Ranger characters to players in a team.
  """

  alias Nostrum.Api
  require Logger

  @impl true
  def call_slash() do
    :random.seed(:erlang.now)
    Logger.info("Received a HOTG slash command")

    ranger_list = [
      "Beast Morphers Blue", "Beast Morphers Red", "Beast Morphers Yellow",
      "Dino Thunder Black", "Dino Thunder Blue", "Dino Thunder Red", "Dino Thunder White", "Dino Thunder Yellow",
      "Hyper Black", "Hyper Blue", "Hyper Green", "Hyper Pink", "Hyper Red", "Hyper Yellow",
      "Jungle Fury Purple",
      "Lightspeed Titanium",
      "Magna Defender",
      "MMPR Alpha", "MMPR Alpha 2", "MMPR Black", "MMPR Black 2", "MMPR Blue", "MMPR Green", "MMPR Orange", "MMPR Pink", "MMPR Pink 2",
      "MMPR Purple", "MMPR Red", "MMPR Red 2", "MMPR White", "MMPR Yellow", "MMPR Yellow 2",
      "Ninja Storm Green",
      "Ninjor",
      "Omega Black", "Omega Red", "Omega Yellow",
      "Phantom Ranger",
      "Ranger Slayer",
      "Samurai Red",
      "Shadow Ranger",
      "Solar Purple",
      "Space Black", "Space Blue", "Space Pink", "Space Red", "Space Silver", "Space Yellow",
      "Time Pink",
      "Turbo Red",
      "Zeo Blue", "Zeo Gold", "Zeo Green", "Zeo Pink", "Zeo Red", "Zeo Yellow"
    ]

    minion_list = [
      "Putties",
      "Super Putties",
      "Z-Putties",
      "Tengas",
      "Quantrons",
      "Tronics",
      "Mastodon Troopers"
    ]

    monster_list = [
      "Baboo",
      "Black Dragon",
      "Blaze",
      "Blaze & Roxy",
      "Bones",
      "Commander Crayfish",
      "Darkonda",
      "Dayne",
      "Ecliptor",
      "Elsa",
      "Evil Dino Thunder White",
      "Evil Green Ranger",
      "Evil Robot Tommy",
      "Eye Guy",
      "Finster",
      "General Venjix",
      "King Sphinx",
      "Knasty Knight",
      "Madame Woe",
      "Pirantishead",
      "Polluticorn",
      "Prince Gasket",
      "Prince Gasket & Princess Archerina",
      "Princess Archerina",
      "Psycho Black",
      "Psycho Blue",
      "Psycho Green",
      "Psycho Pink",
      "Psycho Red",
      "Psycho Yellow",
      "Pudgy Pig",
      "Pumpkin Rapper",
      "Ranger Slayer",
      "Rhinoblaster",
      "Robogoat",
      "Roxy",
      "Squatt",
      "Squatt & Baboo",
      "Terror Toad",
      "Zeltrax"
    ]

    boss_list = [
      "Astronema",
      "Cyclopsis",
      "Divatox",
      "Goldar",
      "King Mondo",
      "Kiya",
      "Lord Drakkon",
      "Lord Zedd",
      "Louie Kaboom",
      "Master Vile",
      "Mega Goldar",
      "Mesagog",
      "Psycho Rangers",
      "Rita Repulsa",
      "Rito Revolto",
      "Scorpina",
      "Thrax",
      "Triple Threat",
      "Wizard of Deception"
    ]

    players = Enum.take_random(ranger_list, 6)
    minions = Enum.take_random(minion_list, 2)
    monsters = Enum.take_random(monster_list, 2)
    boss = Enum.random(boss_list)

    resp_str = "Rangers: " <> players <> "\n" <> "Minions: " <> minions <> "\n" <> "Monsters: " <> monsters <> "\n" <> "Boss: " <> boss

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
end
