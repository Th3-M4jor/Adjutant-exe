defmodule Adjutant.Cache.Snowflake do
  use Ecto.Type

  def type, do: :integer

  defdelegate cast(snowflake), to: Nostrum.Snowflake
  defdelegate load(snowflake), to: Nostrum.Snowflake, as: :cast

  def dump(snowflake) do
    {:ok, Nostrum.Snowflake.dump(snowflake)}
  end
end
