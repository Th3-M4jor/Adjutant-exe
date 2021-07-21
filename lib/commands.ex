defmodule BnBBot.Commands do
  alias BnBBot.Commands

  require Logger

  def cmd_check(%Nostrum.Struct.Message{} = msg) do
    contents = String.trim(msg.content)
    prefix = Application.fetch_env!(:elixir_bot, :prefix)

    if String.starts_with?(contents, prefix) do
      {_, prefix_removed} = String.split_at(contents, String.length(prefix))
      [cmd_name | args] = String.split(prefix_removed)
      cmd_name = String.downcase(cmd_name, :ascii)
      cmd_call(cmd_name, msg, args)
    end
  end

  @spec cmd_call(String.t(), %Nostrum.Struct.Message{}, [String.t()]) :: any()
  defp cmd_call("ping", %Nostrum.Struct.Message{} = msg, args) do
    Commands.Ping.call(msg, args)
  end

  defp cmd_call("chip", %Nostrum.Struct.Message{} = msg, args) do
    Commands.Chip.call(msg, args)
  end

  defp cmd_call("roll", %Nostrum.Struct.Message{} = msg, args) do
    Commands.Dice.call(msg, args)
  end

  defp cmd_call("help", %Nostrum.Struct.Message{} = msg, args) do
    Commands.Help.call(msg, args)
  end

  # default no args
  defp cmd_call(name, _msg, []) do
    Logger.debug("Command #{name} is unrecognized")
  end

  # default
  defp cmd_call(name, _msg, args) do
    Logger.debug("Command #{name} is unrecognized, args were #{inspect(args)}")
  end
end
