defmodule BnBBot.Command do
  @moduledoc """
  Module for dispatching both text and slash commands
  """

  alias Nostrum.Api
  alias Nostrum.Struct.{Interaction, Message}

  require Logger

  @spec dispatch(Message.t() | Interaction.t()) :: any()
  def dispatch(%Interaction{} = inter) do
    handle_slash_command(inter.data.name, inter)
  end

  def dispatch(%Message{} = msg) do
    BnBBot.Command.Text.dispatch(msg)
  end

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
    BnBBot.Command.Slash.Insults,
    BnBBot.Command.Slash.RemindMe,
    BnBBot.Command.Slash.HOTG.Team
  ]

  @deleted_commands [
    BnBBot.Command.Slash.BNB.Create
  ]

  def setup_commands do
    BnBBot.Command.State.delete_commands(@deleted_commands)
    BnBBot.Command.State.setup_commands(@slash_commands)
  end

  # Generate the command handlers at compile time.
  for cmd <- @slash_commands, Code.ensure_compiled!(cmd) do
    name = cmd.get_create_map()[:name]
    true = function_exported?(cmd, :call, 1)
    true = function_exported?(cmd, :call_slash, 1)

    defp handle_slash_command(unquote(name), %Interaction{} = inter) do
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
