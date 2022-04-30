defmodule BnBBot.Commands.RemindMe do
  @moduledoc """
  Command to set a reminder, uses `Oban` under the hood
  """

  alias Nostrum.Api
  require Logger

  use BnBBot.SlashCmdFn, permissions: :everyone

  @impl true
  @spec call_slash(Nostrum.Struct.Interaction.t()) :: :ignore
  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a remind me command")

    [amt, unit, message] = inter.data.options

    channel_id = get_channel_id(inter)
    schedule_in = schedule_in(amt.value, unit.value)
    timestamp = System.os_time(:second)

    if send_response(inter, schedule_in, message.value) == :ok do
      %{message: message.value, channel_id: channel_id, timestamp: timestamp}
      |> BnBBot.Commands.RemindMe.Worker.new(schedule_in: schedule_in)
      |> Oban.insert!()
    end

    :ignore
  end

  @impl true
  def get_create_map do
    %{
      type: 1,
      name: "remind-me",
      description: "Sets a reminder for yourself in the future",
      options: [
        %{
          type: 4,
          name: "in",
          description: "Sets the time to remind you in",
          min_value: 1,
          max_value: 60,
          required: true
        },
        %{
          type: 3,
          name: "units",
          description: "Sets the units of time to remind you in",
          required: true,
          choices: [
            %{
              name: "minute(s)",
              value: "minutes"
            },
            %{
              name: "hour(s)",
              value: "hours"
            },
            %{
              name: "day(s)",
              value: "days"
            },
            %{
              name: "week(s)",
              value: "weeks"
            },
            %{
              name: "month(s)",
              value: "months"
            }
          ]
        },
        %{
          type: 3,
          name: "to",
          description: "Sets the message to remind you with",
          required: true
        }
      ]
    }
  end

  defp get_channel_id(inter) do
    if is_nil(inter.guild_id) do
      inter.channel_id
    else
      Api.create_dm!(inter.member.user.id).id
    end
  end

  defp schedule_in(1, unit) do
    case unit do
      "minutes" ->
        {1, :minute}

      "hours" ->
        {1, :hour}

      "days" ->
        {1, :day}

      "weeks" ->
        {1, :week}

      "months" ->
        {4, :weeks}
    end
  end

  defp schedule_in(amt, unit) do
    case unit do
      "minutes" ->
        {amt, :minutes}

      "hours" ->
        {amt, :hours}

      "days" ->
        {amt, :days}

      "weeks" ->
        {amt, :weeks}

      "months" ->
        {4 * amt, :weeks}
    end
  end

  defp send_response(inter, {reminder_in, reminder_in_units}, reminder_to) do
    if String.length(reminder_to) > 1500 do
      Logger.info("Reminder too long, sending error message")

      Api.create_interaction_response!(inter, %{
        type: 4,
        data: %{
          content: "Your reminder was too long to send, please try again with a shorter message",
          flags: 64
        }
      })

      {:error, "Reminder too long"}
    else
      Api.create_interaction_response!(inter, %{
        type: 4,
        data: %{
          content: "In #{reminder_in} #{reminder_in_units} I'll remind you to:\n\n#{reminder_to}",
          flags: 64
        }
      })

      :ok
    end
  end
end

defmodule BnBBot.Commands.RemindMe.Worker do
  @queue_name :elixir_bot |> Application.compile_env!(:remind_me_queue)

  alias Nostrum.Api

  use Oban.Worker, queue: @queue_name

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"message" => msg, "channel_id" => channel_id, "timestamp" => original_timestamp}
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

    :ok
  end

  def queue_name do
    @queue_name
  end
end
