defmodule BnBBot.Workers.MessageEdit do
  @moduledoc """
  Oban worker for handling scheduled message edits
  """
  @queue_name :elixir_bot |> Application.compile_env!(:edit_message_queue)

  require Logger

  alias Nostrum.Api

  use Oban.Worker, queue: @queue_name

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "channel_id" => channel_id,
          "message_id" => message_id,
          "content" => content,
          "components" => components
        }
      }) do
    channel_id = channel_id |> Nostrum.Snowflake.cast!()
    message_id = message_id |> Nostrum.Snowflake.cast!()

    Api.edit_message(channel_id, message_id, %{
      content: content,
      components: components
    })
    |> case do
      {:ok, _} ->
        :ok

      {:error, err} ->
        Logger.warn("Error editing message: #{err}")
        {:error, err}
    end
  end

  def perform(%Oban.Job{
        args: %{"channel_id" => channel_id, "message_id" => message_id, "content" => content}
      }) do
    channel_id = channel_id |> Nostrum.Snowflake.cast!()
    message_id = message_id |> Nostrum.Snowflake.cast!()

    Api.edit_message(channel_id, message_id, %{
      content: content
    })
    |> case do
      {:ok, _} ->
        :ok

      {:error, err} ->
        Logger.warn("Error editing message: #{err}")
        {:error, err}
    end
  end
end
