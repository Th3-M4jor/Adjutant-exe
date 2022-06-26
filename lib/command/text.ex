defmodule BnBBot.Command.Text do
  @moduledoc """
  Defines the behaviour to be used by text based commands.
  """

  alias BnBBot.Command.Text.{Audit, Debug, Die, ShutUp}
  alias Nostrum.Struct.Message

  @typedoc """
  Who can use the command?
  """
  @type command_perms :: :everyone | :admin | :owner

  @typedoc """
  The name of the command
  """
  @type command_name :: String.t()

  @typedoc """
  The description of the command
  """
  @type command_desc :: String.t()

  @prefix :elixir_bot |> Application.compile_env!(:prefix)

  @spec dispatch(Message.t()) :: :ignore
  def dispatch(%Message{content: <<@prefix, rest::binary>>} = msg) do
    contents = String.trim(rest)
    perms = BnBBot.Util.get_user_perms(msg)

    if perms == :owner do
      [cmd_name | args] = String.split(contents)
      cmd_call(cmd_name, msg, args)
    end

    :ignore
  end

  # Catchall clause that does nothing to avoid errors
  def dispatch(_), do: :ignore

  defp cmd_call("die", msg, args) do
    Die.call(msg, args)
  end

  defp cmd_call("debug", msg, args) do
    Debug.call(msg, args)
  end

  defp cmd_call("shut_up", msg, args) do
    ShutUp.call(msg, args)
  end

  defp cmd_call("audit", msg, args) do
    Audit.call(msg, args)
  end

  # default
  defp cmd_call(_name, _msg, _args) do
    :ignore
  end
end
