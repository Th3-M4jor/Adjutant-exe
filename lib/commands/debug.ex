defmodule BnBBot.Commands.Debug do
  alias Nostrum.Api
  require Logger


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
