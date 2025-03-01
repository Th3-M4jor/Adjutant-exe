defmodule Adjutant.Cache.MessageSchema do
  @moduledoc """
  Ecto schema for message cache
  """

  use Ecto.Schema

  alias Adjutant.Cache.Snowflake, as: Snowflake
  alias Adjutant.Cache.CacheData, as: CacheData

  @primary_key false
  schema "messages" do
    field :message_id, Snowflake, primary_key: true
    field :channel_id, Snowflake
    field :author_id, Snowflake
    field :data, CacheData
  end

  def cast(cached_struct \\ %__MODULE__{}, message) do
    data = %{
      message_id: message.id,
      channel_id: message.channel_id,
      author_id: message.author.id,
      data: message
    }

    Ecto.Changeset.cast(
      cached_struct,
      data,
      ~w[message_id channel_id author_id data]a
    )
  end
end
