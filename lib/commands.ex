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

  defp parse_cmd(%Nostrum.Struct.Message{} = msg, :owner) do
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
    :ignore
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
