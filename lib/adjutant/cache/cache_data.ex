defmodule Adjutant.Cache.CacheData do
  @moduledoc """
  Ecto Type that dumps and loads data
  to and from Erlang ETF.
  """

  use Ecto.Type

  def type, do: :binary

  def cast(data) do
    {:ok, data}
  end

  def load(data) when is_binary(data) do
    {:ok, :erlang.binary_to_term(data)}
  end

  def dump(data) do
    {:ok, :erlang.term_to_binary(data, [:compressed])}
  end
end
