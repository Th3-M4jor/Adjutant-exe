defmodule Adjutant.Command.Slash.Ping do
  @moduledoc """
  Ping command.

  Gets bot latency, as well as uptime and RAM and CPU usage.
  """

  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  require Logger

  @backend_node_name Application.compile_env!(:adjutant, :backend_node_name)
  @webhook_node_name Application.compile_env!(:adjutant, :webhook_node_name)

  use Adjutant.Command.Slash, permissions: :everyone

  @impl true
  @spec call_slash(Nostrum.Struct.Interaction.t()) :: :ignore
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a ping command")

    utilization_task =
      Task.async(fn ->
        Enum.take(:scheduler.utilization(1), 2)
      end)

    memory_usage_task =
      Task.async(fn ->
        bot_memory_usage = round(:erlang.memory(:total) / (1024 * 1024))
        total_memory_usage = bot_memory_usage + get_cross_node_memory_usage()
        {bot_memory_usage, total_memory_usage}
      end)

    now = System.monotonic_time()

    Api.Interaction.create_response(inter, %{
      type: 5
    })

    elapsed = System.monotonic_time() - now

    [
      [
        {:total, _, total_percent},
        {:weighted, _, weighted_percent}
      ],
      {bot_memory_usage, total_memory_usage}
    ] = Task.await_many([utilization_task, memory_usage_task], :infinity)

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
        %Embed.Field{
          name: "Uptime:",
          value: get_uptime_str()
        },
        %Embed.Field{
          name: "Memory:",
          value: """
          Bot memory usage is #{bot_memory_usage} MiB
          BEAM VM memory usage is #{total_memory_usage} MiB
          """
        },
        %Embed.Field{
          name: "Bot CPU usage:",
          value: """
          total: #{total_percent}
          weighted: #{weighted_percent}
          """
        },
        %Embed.Field{
          name: "Active bot processes:",
          value: length(Process.list())
        }
      ]
    }

    Api.Interaction.edit_response(inter, %{
      content: "",
      embeds: [ping_embed]
    })

    :ignore
  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "ping",
      description: "Check bot latency, and get other info"
    }
  end

  defp get_uptime_str do
    Logger.debug("Generating system uptime")
    {uptime, _} = :erlang.statistics(:wall_clock)
    uptime_seconds = System.convert_time_unit(uptime, :millisecond, :second)

    startup_time = System.os_time(:second) - uptime_seconds

    "Bot was last restarted <t:#{startup_time}:R>"
  end

  defp get_cross_node_memory_usage do
    Logger.debug("Getting cross node memory usage")

    backend_task = Task.async(fn -> backend_usage() end)
    webhook_task = Task.async(fn -> webhook_usage() end)

    sum =
      [backend_task, webhook_task]
      |> Task.await_many(:infinity)
      |> Enum.sum()

    round(sum / (1024 * 1024))
  end

  defp backend_usage do
    Logger.debug("Getting backend usage")

    if Node.alive?() and Node.connect(@backend_node_name) do
      {:ok, backend_memory_usage} = :erpc.call(@backend_node_name, :erlang, :memory, [:total])

      backend_memory_usage
    else
      0
    end
  end

  defp webhook_usage do
    Logger.debug("Getting webhook usage")

    if Node.alive?() and Node.connect(@webhook_node_name) do
      {:ok, webhook_memory_usage} = :erpc.call(@webhook_node_name, :erlang, :memory, [:total])

      webhook_memory_usage
    else
      0
    end
  end
end
