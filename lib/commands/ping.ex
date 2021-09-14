defmodule BnBBot.Commands.Ping do
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  require Logger

  @behaviour BnBBot.SlashCmdFn

  @spec call_slash(Nostrum.Struct.Interaction.t()) :: :ignore
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.debug("Recieved a ping command")

    utilization_task = Task.async(fn ->
      :scheduler.utilization(1) |> Enum.take(2)
    end)

    now = System.monotonic_time()

    {:ok} = Api.create_interaction_response(inter, %{
      type: 5
    })

    elapsed = System.monotonic_time() - now

    [
      {:total, _, total_percent},
      {:weighted, _, weighted_percent},
    ] = Task.await(utilization_task)

    #  {:ok, response} =
    #    Api.create_message(
    #      inter.channel_id,
    #      content: "Checking response times..."
    #    )


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
        %Embed.Field{name: "Memory:", value: "BEAM VM memory usage is #{memory_usage} MiB"},
        %Embed.Field{name: "CPU usage:", value: "total: #{total_percent}\nweighted: #{weighted_percent}"},
      ]
    }

    route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

    :ok = Api.request(:patch, route, %{
      content: "",
      embeds: [ping_embed],
    }) |> elem(0)

    #Api.execute_webhook(
    #  inter.application_id,
    #  inter.token,
    #  %{
    #    content: "",
    #    embeds: [ping_embed]
    #  },
    #  true
    #)

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
