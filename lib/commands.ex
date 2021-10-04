defmodule BnBBot.Commands do
  alias BnBBot.Commands
  alias Nostrum.Api

  require Logger

  @spec cmd_check(Nostrum.Struct.Message.t()) :: :ignore | nil
  def cmd_check(%Nostrum.Struct.Message{} = msg) do
    contents = String.trim(msg.content)
    prefix = Application.fetch_env!(:elixir_bot, :prefix)
    prefix_len = String.length(prefix)
    perms = BnBBot.Util.get_user_perms(msg)

    case {contents, perms} do
      {<<^prefix::binary-size(prefix_len), "">>, perms} when perms in [:owner, :admin] ->
        :ignore

      {<<^prefix::binary-size(prefix_len), _rest::binary>>, :everyone} ->
        Api.create_message(
          msg.channel_id,
          content: "I'm sorry, text based commands have been removed in favor of slash commands",
          message_reference: %{message_id: msg.id}
        )

      {<<^prefix::binary-size(prefix_len), "reload">>, :admin} ->
        Commands.Reload.call(msg, [])

      {<<^prefix::binary-size(prefix_len), rest::binary>>, :owner} ->
        [cmd_name | args] = String.split(rest)
        cmd_call(cmd_name, msg, args)

      _ ->
        nil
    end
    :ignore
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

  defp cmd_call("audit", msg, args) do
    Commands.Audit.call(msg, args)
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
