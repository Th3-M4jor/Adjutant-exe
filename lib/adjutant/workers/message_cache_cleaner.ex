defmodule Adjutant.Workers.MessageCacheCleaner do
  @moduledoc """
  Oban worker for cleaning up old message cache entries
  """

  require Logger

  use Oban.Worker, queue: :clean_message_cache

  import Ecto.Query, only: [from: 2]

  alias Adjutant.Cache.MessageSchema

  @impl Oban.Worker
  def perform(_job) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.shift(day: -29)

    snowflake = Nostrum.Util.timestamp_like_to_snowflake(cutoff)

    Logger.info("Cleaning up message cache entries older than #{cutoff}")

    query = from(m in MessageSchema, where: m.id < ^snowflake)

    Adjutant.Repo.MessageCacheRepo.delete_all(query)

    :ok
  end
end
