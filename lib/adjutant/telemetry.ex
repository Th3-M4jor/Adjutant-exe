defmodule Adjutant.Telemetry do
  @moduledoc """
  Event handler for telemetry events.
  """

  require Logger

  def init do
    Logger.debug("Attaching telemetry handlers")

    :telemetry.attach_many(
      :adjutant_telemetry,
      [
        ~w[nostrum api request start]a,
        ~w[nostrum api request stop]a,
        ~w[nostrum api request exception]a,
        ~w[nostrum ratelimiter connected]a,
        ~w[nostrum ratelimiter postponed]a,
        ~w[nostrum ratelimiter disconnected]a
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:nostrum, :api, :request | rest], measurements, metadata, _config) do
    Logger.debug("API Request: #{inspect(rest)}: #{inspect(measurements)} #{inspect(metadata)}")
  end

  def handle_event([:nostrum, :ratelimiter | rest], measurements, metadata, _config) do
    Logger.debug("Ratelimiter: #{inspect(rest)}: #{inspect(measurements)} #{inspect(metadata)}")
  end
end
