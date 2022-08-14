defmodule BnBBot.Workers.LogCleaner do
  @moduledoc """
  Oban worker for cleaning up the log table periodically
  """
  @queue_name :elixir_bot |> Application.compile_env!(:log_cleaner_queue)

  require Logger
  use Oban.Worker, queue: @queue_name
  import Ecto.Query
  alias BnBBot.LogLine

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Cleaning up log table")

    # Delete all log entries older than 1 month

    one_month_ago =
      NaiveDateTime.local_now()
      |> NaiveDateTime.add(-30 * 24 * 60 * 60)

    from(l in LogLine,
      where: l.inserted_at < ^one_month_ago
    )
    |> BnBBot.Repo.SQLite.delete_all()

    # Run VACUUM to free up space
    BnBBot.Repo.SQLite.query!("VACUUM")

    :ok
  end
end
