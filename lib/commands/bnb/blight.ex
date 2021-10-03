defmodule BnBBot.Commands.Blight do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.SlashCmdFn

  @blight_elements [
    "Fire",
    "Aqua",
    "Elec",
    "Wood",
    "Wind",
    "Sword",
    "Break",
    "Cursor",
    "Recov",
    "Invis",
    "Object"
  ]

  @fire "```\nFire:\nWhen attacking, if your attack uses Strength or Agility to hit you must make it with disadvantage.\n```"
  @aqua "```\nAqua:\nYou may only make half your maximum Move Actions on your turn (minimum 1).\n```"
  @elec "```\nElec:\nInstead of taking damage at the start of your turn, you will take the damage listed by the Blight effect every time you make a Move Action.\n```"
  @wood "```\nWood:\nDamage done by Blight restores HP to the target who dealt it.\n```"
  @wind "```\nWind:\nWhen attacking, if your attack uses Perception or Agility to hit you must make it with disadvantage.\n```"
  @sword "```\nSword:\nWhen you deal damage to a target in your Close range, that target takes damage equal to half the result of your damage roll instead of the full amount.\n```"
  @break "```\nBreak:\nEvery time you make a Move Action, you must make an Endurance Check or you will be considered Staggered.\n```"
  @cursor "```\nCursor:\nWhen you use a Battlechip, you must make a Tech check of a given DC or lose an Attack Action on top of the action used for the chip.\n```"
  @recov "```\nRecov:\nYou are unable to heal from any source.\n```"
  @invis "```\nInvis:\nWhen you deal damage to a target in your Near range or beyond, the target takes damage equal to half the result of your damage roll instead of the full amount.\n```"
  @object "```\nObject:\nAt the start of each turn, make an Info Check of a given DC. Should you fail, the target that Blighted you steals one chip from your Folder if any are present there.\n```"

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a blight command")

    resp_str =
      case inter.data.options do
        [arg] ->
          blight_to_str(arg.value)

        _ ->
          Logger.warn(["Blight: bad argument given ", inspect(inter.data.options)])
          "An unknown error has occurred"
      end

    {:ok} =
      Api.create_interaction_response(
        inter,
        %{
          type: 4,
          data: %{
            content: resp_str
          }
        }
      )

    :ignore
  end

  def get_create_map() do
    choices =
      Enum.map(@blight_elements, fn name ->
        %{
          name: name,
          value: name
        }
      end)

    %{
      type: 1,
      name: "blight",
      description: "Get info about a blight",
      options: [
        %{
          type: 3,
          name: "element",
          description: "The blight to get info about",
          required: true,
          choices: choices
        }
      ]
    }
  end

  defp blight_to_str(name) do
    case name do
      "Fire" ->
        @fire

      "Aqua" ->
        @aqua

      "Elec" ->
        @elec

      "Wood" ->
        @wood

      "Wind" ->
        @wind

      "Sword" ->
        @sword

      "Break" ->
        @break

      "Cursor" ->
        @cursor

      "Recov" ->
        @recov

      "Invis" ->
        @invis

      "Object" ->
        @object

      _ ->
        Logger.warn("Got an unknown blight: #{name}")
        "Unknown Blight"
    end
  end
end
