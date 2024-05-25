defmodule Adjutant.Repo.SQLite.Migrations.DropPsychoEffectTables do
  use Ecto.Migration

  def up do
    drop table("psycho_effect_channel")
    drop table("random_insults")
  end

  def down do
    create table("random_insults") do
      add :insult, :text
      timestamps(updated_at: false)
    end

    create table("psycho_effect_channel") do
      add :guild_id, :integer, null: false
      add :set_by, :integer, null: false
      timestamps()
    end
  end
end
