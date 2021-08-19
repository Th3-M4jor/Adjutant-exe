defmodule BnBBot.Commands.Ping do
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  require Logger

  @behaviour BnBBot.CommandFn

  @behaviour BnBBot.SlashCmdFn

  def help() do
    {"ping", :everyone, "Check bot latency, and get other info"}
  end

  def get_name() do
    "ping"
  end

  def full_help() do
    "Returns the latency on creating a message, latency of the websocket, how long the bot has been online for, and it's total memory usage"
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.debug("Recieved a ping command")
    now = System.monotonic_time()

    {:ok, response} =
      Api.create_message(
        msg.channel_id,
        content: "Checking response times...",
        message_reference: %{message_id: msg.id}
      )

    elapsed = System.monotonic_time() - now
    milis = System.convert_time_unit(elapsed, :native, :microsecond) / 1000
    count = :erlang.float_to_binary(milis, decimals: 2)

    # zero since there should only need to be one shard
    latency = Nostrum.Util.get_all_shard_latencies()[0]

    memory_usage = round(:erlang.memory(:total) / (1024 * 1024))

    ping_embed = %Embed{
      title: "\u{1F3D3} Pong!",
      color: 431_948,
      fields: [
        %Embed.Field{name: "API", value: "#{count} ms"},
        %Embed.Field{name: "WS", value: "#{latency} ms"},
        %Embed.Field{
          name: "Uptime:",
          value: get_uptime_str()
        },
        %Embed.Field{name: "Memory:", value: "BEAM VM memory usage is #{memory_usage} MiB"}
      ]
    }

    Api.edit_message(response.channel_id, response.id, content: "", embeds: [ping_embed])
  end

  @spec call_slash(Nostrum.Struct.Interaction.t()) :: :ignore
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.debug("Recieved a ping command")

    now = System.monotonic_time()

    Api.create_interaction_response(inter, %{
      type: 5
    })

    #  {:ok, response} =
    #    Api.create_message(
    #      inter.channel_id,
    #      content: "Checking response times..."
    #    )

    elapsed = System.monotonic_time() - now
    milis = System.convert_time_unit(elapsed, :native, :microsecond) / 1000
    count = :erlang.float_to_binary(milis, decimals: 2)

    # zero since there should only need to be one shard
    latency = Nostrum.Util.get_all_shard_latencies()[0]

    memory_usage = round(:erlang.memory(:total) / (1024 * 1024))

    ping_embed = %Embed{
      title: "\u{1F3D3} Pong!",
      color: 431_948,
      fields: [
        %Embed.Field{name: "API", value: "#{count} ms"},
        %Embed.Field{name: "WS", value: "#{latency} ms"},
        %Embed.Field{
          name: "Uptime:",
          value: get_uptime_str()
        },
        %Embed.Field{name: "Memory:", value: "BEAM VM memory usage is #{memory_usage} MiB"}
      ]
    }

  #  route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

  #  Api.request(:patch, route, %{
  #    content: "",
  #    embeds: [ping_embed],
  #    flags: 0,
  #  })

    Api.execute_webhook(
      inter.application_id,
      inter.token,
      %{
        content: "",
        embeds: [ping_embed]
      },
      true
    )

    # Api.create_message(inter.channel_id, content: "", embeds: [ping_embed])
    :ignore
  end

  def get_create_map() do
    %{
      type: 1,
      name: "ping",
      description: "Check bot latency, and get other info"
    }
  end

  defp get_uptime_str() do
    Logger.debug("Generating system uptime")
    {uptime, _} = :erlang.statistics(:wall_clock)
    uptime_seconds = System.convert_time_unit(uptime, :millisecond, :second)

    # uptime_days = div(uptime_seconds, 24 * 60 * 60)
    # uptime_seconds = rem(uptime_seconds, 24 * 60 * 60)

    # uptime_hours = div(uptime_seconds, 60 * 60)
    # uptime_seconds = rem(uptime_seconds, 60 * 60)

    # uptime_minutes = div(uptime_seconds, 60)
    # uptime_seconds = rem(uptime_seconds, 60)

    startup_time = System.os_time(:second) - uptime_seconds

    # "Bot uptime is #{uptime_days}D:#{uptime_hours}H:#{uptime_minutes}M:#{uptime_seconds}S"
    "Bot was last restarted <t:#{startup_time}:R>"
  end
end
