defmodule BnBBot.Commands.ShutUp do
  @moduledoc """
  Text based command for telling the bot to stop DMing the owner.
  """

  require Logger

  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.info("Recieved a shutup command")

    if BnBBot.Util.is_owner_msg?(msg) do
      res =
        case GenServer.call(:bnb_bot_data, {:get, :dm_owner}) do
          nil -> true
          val when is_boolean(val) -> val
        end

      Logger.debug("Currently set to DM messages: #{res}")
      new_val = not res
      GenServer.cast(:bnb_bot_data, {:insert, :dm_owner, new_val})
      BnBBot.Util.react(msg)
    end
  end
end
