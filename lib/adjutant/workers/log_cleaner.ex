defmodule Adjutant.Workers.LogCleaner do
  @moduledoc """
  Oban worker for cleaning up the log table periodically
  """

  require Logger

  use Oban.Worker, queue: :log_cleaner

  import Ecto.Query

  alias Adjutant.LogLine

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Cleaning up log table")

    # Delete all log entries older than 1 month
    # Delete all info logs older than 1 week
    # Delete all debug logs older than 2 days
    from(l in LogLine,
      where: l.inserted_at < ago(1, "month"),
      or_where: l.inserted_at < ago(1, "week") and l.level == :info,
      or_where: l.inserted_at < ago(2, "day") and l.level == :debug
    )
    |> Adjutant.Repo.SQLite.delete_all()

    # Run VACUUM to free up space
    Adjutant.Repo.SQLite.query!("VACUUM")

    :ok
  end
end
