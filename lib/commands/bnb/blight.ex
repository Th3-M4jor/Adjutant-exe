defmodule BnBBot.Commands.Blight do
  @moduledoc """
  Command for getting the effect of each blight element.
  """

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

  @fire "```\nFire:\nWhen you make damage rolls, the rolled result and maximum result of each die is reduced by 1.\n```"
  @aqua "```\nAqua:\nYour AC is decreased by one until the start of your next turn each time you come into contact with Ice or Sea terrain.\n```"
  @elec "```\nElec:\nTake this Blight's damage when you make Move Actions or get pushed or pulled from one panel to another instead of at the start of your turn.\n```"
  @wood "```\nWood:\nDamage done by Blight restores HP to the target who dealt it.\n```"
  @wind "```\nWind:\nYour maximum number of Move Actions is cut in half. (minimum 1)\n```"
  @sword "```\nSword:\nWhen you make attacks against targets in Close range, they may each make one free attack against you per round.\n```"
  @break "```\nBreak:\nYou are unable to reduce damage dealt to you by Shields, Barriers, Auras, Holy terrain, or any other source.\n```"
  @cursor "```\nCursor:\nYou may only make Near attacks at Close range. Far attacks have their range limited to Near.\n```"
  @recov "```\nRecov:\nYou are unable to heal from any source.\n```"
  @invis "```\nInvis:\nYou are unable to inflict Statuses on any target or grant them to allies.\n```"
  @object "```\nObject:\nYou make all attack rolls with disadvantage.\n```"

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

  def get_create_map do
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

  # credo:disable-for-lines:30 Credo.Check.Refactor.CyclomaticComplexity
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
