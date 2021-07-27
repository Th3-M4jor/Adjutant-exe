defmodule BnBBot.Commands.ShutUp do
  require Logger

  @behaviour BnBBot.CommandFn

  def help() do
    {"shut_up", :owner, "Reduces the number of messages the bot DMs you"}
  end

  def get_name() do
    "shut_up"
  end

  def full_help() do
    "Bot no longer DMs owner on resume events"
  end

  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.debug("Recieved a shutup command")

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
