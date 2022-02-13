defmodule BnBBot.Commands do
  @moduledoc """
  This module handles dispatch on the remaining text based commands.
  All are owner/admin only, and are not available to the public.
  """

  alias BnBBot.Commands
  # alias Nostrum.Api

  require Logger

  @prefix :elixir_bot |> Application.compile_env!(:prefix)

  @spec cmd_check(Nostrum.Struct.Message.t()) :: :ignore | nil
  def cmd_check(%Nostrum.Struct.Message{} = msg) do
    contents = String.trim(msg.content)
    perms = BnBBot.Util.get_user_perms(msg)

    case {contents, perms} do
      {<<@prefix, "">>, _} ->
        nil

      {<<@prefix, rest::binary>>, :owner} ->
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
