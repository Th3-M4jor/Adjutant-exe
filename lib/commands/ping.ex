defmodule BnBBot.Commands.Ping do
  alias Nostrum.Api
  require Logger

  def help() do
    {"ping", "Check message latency"}
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.debug("Recieved a ping command")
    now = System.monotonic_time()

    {:ok, response} =
      Api.create_message(
        msg.channel_id,
        content: "Checking times",
        message_reference: %{message_id: msg.id}
      )

    elapsed = System.monotonic_time() - now
    milis = System.convert_time_unit(elapsed, :native, :microsecond) / 1000
    count = :erlang.float_to_binary(milis, decimals: 2)
    Api.edit_message(response.channel_id, response.id, "\u{1F3D3} Pong! that took #{count} ms")
  end
end
