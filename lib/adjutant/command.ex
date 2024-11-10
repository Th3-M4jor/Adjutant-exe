defmodule Adjutant.Command do
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
    Adjutant.Command.Text.dispatch(msg)
  end

  @slash_commands [
    Adjutant.Command.Slash.Dice,
    Adjutant.Command.Slash.Ping,
    Adjutant.Command.Slash.Shuffle,
    Adjutant.Command.Slash.Hidden,
    Adjutant.Command.Slash.RemindMe,
    Adjutant.Command.Slash.HOTG.Team
  ]

  @deleted_commands []

  def setup_commands do
    Adjutant.Command.State.delete_commands(@deleted_commands)
    Adjutant.Command.State.setup_commands(@slash_commands)
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
    Logger.warning("slash command #{name} doesn't exist")

    {:ok} = Api.Interaction.create_response(
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
