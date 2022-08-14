defmodule BnBBot.Workers.Reminder do
  @moduledoc """
  Oban worker for handling scheduled reminders
  """

  @queue_name :elixir_bot |> Application.compile_env!(:remind_me_queue)

  alias Nostrum.Api

  use Oban.Worker, queue: @queue_name

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "message" => msg,
            "channel_id" => channel_id,
            "timestamp" => original_timestamp
          } = args
      }) do
    now = System.os_time(:second)
    time_diff = now - original_timestamp

    # 5 days in seconds
    text =
      if time_diff > 5 * 24 * 60 * 60 do
        "On <t:#{original_timestamp}:F> you wanted a reminder to: #{msg}"
      else
        "<t:#{original_timestamp}:R> you wanted a reminder to: #{msg}"
      end

    Api.create_message!(channel_id, text)

    if args["repeat"] == true do
      [period, units] = args["interval"]

      Task.start(BnBBot.Command.Slash.RemindMe, :reschedule_reminder, [
        channel_id,
        msg,
        {period, units}
      ])
    end

    :ok
  end

  def queue_name do
    @queue_name
  end
end
