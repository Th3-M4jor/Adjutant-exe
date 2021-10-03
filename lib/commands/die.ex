defmodule BnBBot.Commands.Die do
  require Logger

  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.info("Recieved a die command")

    if BnBBot.Util.is_owner_msg?(msg) do
      BnBBot.Util.react(msg, true)
      System.stop(0)
    end
  end
end
