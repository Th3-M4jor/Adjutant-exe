defmodule Adjutant.Repo.MessageCacheRepo do
  @moduledoc """
  A separate sqlite repo for message cache.
  """
  use Ecto.Repo, otp_app: :adjutant, adapter: Ecto.Adapters.SQLite3
end
