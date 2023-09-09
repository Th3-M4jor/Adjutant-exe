defmodule BnBBot.Workers.LogCleaner do
  @moduledoc """
  Oban worker for cleaning up the log table periodically
  """

  require Logger

  use Oban.Worker, queue: :log_cleaner

  import Ecto.Query

  alias BnBBot.LogLine

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Cleaning up log table")

    # Delete all log entries older than 1 month

    # now = NaiveDateTime.local_now()

    # one_month_ago = NaiveDateTime.add(now, -30 * 24 * 60 * 60)

    # one_week_ago = NaiveDateTime.add(now, -7 * 24 * 60 * 60)

    from(l in LogLine,
      where: l.inserted_at < ago(1, "month"),
      or_where: l.inserted_at < ago(1, "week") and l.level == :debug
    )
    |> BnBBot.Repo.SQLite.delete_all()

    # Run VACUUM to free up space
    BnBBot.Repo.SQLite.query!("VACUUM")

    :ok
  end
end
