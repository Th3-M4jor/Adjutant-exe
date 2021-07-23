defmodule BnBBot.Commands do
  alias BnBBot.Commands
  alias Nostrum.Api

  require Logger

  def cmd_check(%Nostrum.Struct.Message{} = msg) do
    contents = String.trim(msg.content)
    prefix = Application.fetch_env!(:elixir_bot, :prefix)

    if String.starts_with?(contents, prefix) do
      {_, prefix_removed} = String.split_at(contents, String.length(prefix))
      # [cmd_name | args] = String.split(prefix_removed)
      {cmd_name, args} =
        case String.split(prefix_removed) do
          [cmd_name | args] ->
            lowercase_name = String.downcase(cmd_name, :ascii)
            {lowercase_name, args}

          [] ->
            {:prefix_only, []}
        end

      cmd_call(cmd_name, msg, args)
    end
  end

  @spec cmd_call(String.t() | :prefix_only, %Nostrum.Struct.Message{}, [String.t()]) :: any()
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

  defp cmd_call("die", %Nostrum.Struct.Message{} = msg, args) do
    Commands.Die.call(msg, args)
  end

  defp cmd_call("debug", %Nostrum.Struct.Message{} = msg, args) do
    Commands.Debug.call(msg, args)
  end

  defp cmd_call("shut_up", %Nostrum.Struct.Message{} = msg, args) do
    Commands.ShutUp.call(msg, args)
  end

  defp cmd_call(:prefix_only, msg, []) do
    Logger.debug("Recieved a prefix only")
    Api.create_message(
      msg.channel_id,
      content: "You gave me only my prefix, Try my help command for how I work",
      message_reference: %{message_id: msg.id}
    )
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
