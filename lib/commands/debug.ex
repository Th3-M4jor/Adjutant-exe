defmodule BnBBot.Commands.Debug do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.CommandFn

  def help() do
    {"debug", :owner, "Enables or Disables debug logging"}
  end

  def get_name() do
    "debug"
  end

  def full_help() do
    "Use with argument \"on\" to enable (default) or use with \"off\" to disable, this data can be grabbed from the audit command"
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, []) do
    Logger.debug("Got a debug cmd with no args")

    if BnBBot.Util.is_owner_msg?(msg) do
      Logger.configure(level: :debug)
      BnBBot.Util.react(msg, true)
    end
  end

  def call(%Nostrum.Struct.Message{} = msg, ["on"]) do
    if BnBBot.Util.is_owner_msg?(msg) do
      Logger.configure(level: :debug)
      BnBBot.Util.react(msg, true)
    end
  end

  def call(%Nostrum.Struct.Message{} = msg, ["off"]) do
    if BnBBot.Util.is_owner_msg?(msg) do
      Logger.configure(level: :warning)
      BnBBot.Util.react(msg, true)
    end
  end

  def call(%Nostrum.Struct.Message{} = msg, _args) do
    if BnBBot.Util.is_owner_msg?(msg) do
      Api.create_message(
        msg.channel_id,
        "I'm sorry, that is not a valid argument to the Debug command"
      )

      BnBBot.Util.react(msg, false)
    end
  end
end
