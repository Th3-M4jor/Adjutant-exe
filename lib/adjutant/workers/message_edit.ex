defmodule Adjutant.Workers.MessageEdit do
  @moduledoc """
  Oban worker for handling scheduled message edits
  """

  require Logger

  alias Nostrum.Api

  use Oban.Worker, queue: :edit_message

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "channel_id" => channel_id,
          "message_id" => message_id,
          "content" => content,
          "components" => components
        }
      }) do
    Nostrum.Bot.set_bot_name(:adjutant)

    res =
      Api.Message.edit(channel_id, message_id, %{
        content: content,
        components: components
      })

    case res do
      {:ok, _} ->
        :ok

      {:error, err} ->
        Logger.warning("Error editing message: #{err}")
        {:error, err}
    end
  end

  def perform(%Oban.Job{
        args: %{"channel_id" => channel_id, "message_id" => message_id, "content" => content}
      }) do
    Nostrum.Bot.set_bot_name(:adjutant)

    Api.Message.edit(channel_id, message_id, %{
      content: content
    })
    |> case do
      {:ok, _} ->
        :ok

      {:error, err} ->
        Logger.warning("Error editing message: #{err}")
        {:error, err}
    end
  end
end
