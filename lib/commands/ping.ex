defmodule BnBBot.Commands.Ping do
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  require Logger

  def help() do
    {"ping", "Check bot latency"}
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

    # zero since there should only need to be one shard
    latency = Nostrum.Util.get_all_shard_latencies()[0]

    ping_embed = %Embed{
      title: "\u{1F3D3} Pong!",
      color: 431_948,
      fields: [
        %Embed.Field{name: "API", value: "#{count} ms"},
        %Embed.Field{name: "WS", value: "#{latency} ms"},
      ]
    }

    Api.edit_message(response.channel_id, response.id, embeds: [ping_embed])
  end
end
