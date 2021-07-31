defmodule BnBBot.Commands.Chip do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.CommandFn

  def help() do
    {"chip", :everyone, "Get info about a battlechip"}
  end

  def get_name() do
    "chip"
  end

  def full_help() do
    "Search for a chip with the given name, returns full data on it, currently unimplemented"
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.debug("Recieved a chip command")

    react_task = Task.async(fn -> BnBBot.Util.react(msg, false) end)

    dm_task =
      Task.async(fn ->
        channel_id = BnBBot.Util.find_dm_channel_id(msg.author.id)
        Api.create_message!(channel_id, "I'm sorry, this command isn't implemented yet")
      end)

    Task.await_many([react_task, dm_task])
  end
end
