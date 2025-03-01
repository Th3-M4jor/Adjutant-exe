defmodule Adjutant.Repo.MessageCacheRepo.Migrations.AddMessageCache do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :message_id, :string, primary_key: true
      add :channel_id, :string
      add :author_id, :string
      add :data, :binary
    end

    create index(:messages, [:channel_id, :author_id, :message_id])
    create index(:messages, [:author_id, :message_id])
    create index(:messages, [:channel_id, :message_id])
  end
end
