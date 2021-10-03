defmodule BnBBot.Commands.ShutUp do
  require Logger

  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.info("Recieved a shutup command")

    if BnBBot.Util.is_owner_msg?(msg) do
      res =
        case :ets.lookup(:bnb_bot_data, :dm_owner) do
          [dm_owner: val] -> val
          _ -> true
        end

      Logger.debug("Currently set to DM messages: #{res}")
      new_val = not res
      :ets.insert(:bnb_bot_data, dm_owner: new_val)
      BnBBot.Util.react(msg)
    end
  end
end
