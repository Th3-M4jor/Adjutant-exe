defmodule Adjutant.Repo.SQLite.Migrations.DropLogTable do
  use Ecto.Migration

  def change do
    drop table(:bot_log)
  end
end
