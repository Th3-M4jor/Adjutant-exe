defmodule BnBBot.Commands do
  alias BnBBot.Commands
  alias Nostrum.Api

  require Logger

  @spec cmd_check(Nostrum.Struct.Message.t()) :: :ignore | nil
  def cmd_check(%Nostrum.Struct.Message{} = msg) do
    contents = String.trim(msg.content)
    prefix = Application.fetch_env!(:elixir_bot, :prefix)

    if String.starts_with?(contents, prefix) do
      perms = BnBBot.Util.get_user_perms(msg)
      parse_cmd(msg, perms)
      :ignore
    end
  end

  @spec parse_cmd(Nostrum.Struct.Message.t(), :owner | :admin | :everyone) :: any()
  defp parse_cmd(msg, :owner) do
    contents = String.trim(msg.content)
    prefix = Application.fetch_env!(:elixir_bot, :prefix)
    {_, prefix_removed} = String.split_at(contents, String.length(prefix))

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

  defp parse_cmd(msg, :admin) do
    contents = String.trim(msg.content)
    prefix = Application.fetch_env!(:elixir_bot, :prefix)
    {_, prefix_removed} = String.split_at(contents, String.length(prefix))

    {cmd_name, args} =
      case String.split(prefix_removed) do
        [cmd_name | args] ->
          lowercase_name = String.downcase(cmd_name, :ascii)
          {lowercase_name, args}

        [] ->
          {:prefix_only, []}
      end

    case cmd_name do
      :prefix_only ->
        {:ignore, nil}

      "reload" ->
        Commands.Reload.call(msg, args)

      _ ->
        Api.create_message(
          msg.channel_id,
          content: "I'm sorry, all but one command for admin use has been removed",
          message_reference: %{message_id: msg.id}
        )
    end
  end

  defp parse_cmd(msg, :everyone) do
    Api.create_message(
      msg.channel_id,
      content: "I'm sorry, text based commands have been removed in favor of slash commands",
      message_reference: %{message_id: msg.id}
    )
  end

  @spec cmd_call(String.t() | :prefix_only, %Nostrum.Struct.Message{}, [String.t()]) :: any()
  defp cmd_call(:prefix_only, msg, []) do
    Logger.debug("Recieved a prefix only")

    Api.create_message(
      msg.channel_id,
      content: "You gave me only my prefix, Try my help command for how I work",
      message_reference: %{message_id: msg.id}
    )
  end

  # defp cmd_call("ping", msg, args) do
  #   Commands.Ping.call(msg, args)
  # end
  #
  # defp cmd_call("chip", msg, args) do
  #   Commands.Chip.call(msg, args)
  # end
  #
  # defp cmd_call("c", msg, args) do
  #   Commands.Chip.call(msg, args)
  # end
  #
  # defp cmd_call("ncp", msg, args) do
  #   Commands.NCP.call(msg, args)
  # end
  #
  # defp cmd_call("n", msg, args) do
  #   Commands.NCP.call(msg, args)
  # end
  #
  # defp cmd_call("phb", msg, args) do
  #   Commands.PHB.call(msg, args)
  # end
  #
  # defp cmd_call("roll", msg, args) do
  #   Commands.Dice.call(msg, args)
  # end
  #
  # defp cmd_call("shuffle", msg, args) do
  #   Commands.Shuffle.call(msg, args)
  # end
  #
  # defp cmd_call("help", msg, args) do
  #   Commands.Help.call(msg, args)
  # end

  defp cmd_call("die", msg, args) do
    Commands.Die.call(msg, args)
  end

  defp cmd_call("debug", msg, args) do
    Commands.Debug.call(msg, args)
  end

  defp cmd_call("shut_up", msg, args) do
    Commands.ShutUp.call(msg, args)
  end

  defp cmd_call("reload", msg, args) do
    Commands.Reload.call(msg, args)
  end

  # default
  defp cmd_call(_name, _msg, _args) do
    # few enough args so it should be fine
    # args = [name] ++ args

    # Commands.All.search(msg, args)
    :ignore
    # case args do
    #  [] ->
    #    Logger.debug(["Command \"", name, "\" is unrecognized"])
    #
    #  _ ->
    #    Logger.debug(["Command \"", name, "\" is unrecognized, args were ", inspect(args)])
    # end
  end
end
