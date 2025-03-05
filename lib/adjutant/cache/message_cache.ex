defmodule Adjutant.Cache.MessageCache do
  @moduledoc """
  Ecto based cache adapter for Nostrum
  """

  @behaviour Nostrum.Cache.MessageCache

  use Supervisor

  alias Adjutant.Cache.MessageSchema
  alias Adjutant.Repo.MessageCacheRepo

  import Ecto.Query, only: [from: 2]

  @doc "Start the supervisor."
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc "Start up the cache supervisor."
  @impl Supervisor
  def init(_init_arg) do
    Supervisor.init([], strategy: :one_for_one)
  end

  @impl Nostrum.Cache.MessageCache
  def get(message_id) do
    case MessageCacheRepo.get(MessageSchema, message_id) do
      nil -> {:error, :message_not_found}
      %MessageSchema{data: message} -> {:ok, message}
    end
  end

  @impl Nostrum.Cache.MessageCache
  def create(message) do
    message = Nostrum.Struct.Message.to_struct(message)
    MessageSchema.cast(message) |> MessageCacheRepo.insert_or_update!()

    message
  end

  @impl Nostrum.Cache.MessageCache
  def update(payload) do
    atomized_payload =
      payload
      |> Map.new(fn {k, v} -> {Nostrum.Util.maybe_to_atom(k), v} end)

    %{id: id} = atomized_payload
    id = Nostrum.Snowflake.cast!(id)

    old_message = MessageCacheRepo.get(MessageSchema, id)

    case old_message do
      nil ->
        # we don't have the old message, so we shouldn't
        # save it in the cache as updates are not guaranteed
        # to have the full message payload
        updated_message = Nostrum.Struct.Message.to_struct(atomized_payload)
        {nil, updated_message}

      %MessageSchema{data: old_message} = old_cache_struct ->
        updated_message = Nostrum.Struct.Message.to_struct(atomized_payload, old_message)

        MessageSchema.cast(
          old_cache_struct,
          updated_message
        )
        |> MessageCacheRepo.update!()

        {old_message, updated_message}
    end
  end

  @impl Nostrum.Cache.MessageCache
  def delete(channel_id, message_id) do
    case MessageCacheRepo.get(MessageSchema, message_id) do
      %MessageSchema{data: message, channel_id: ^channel_id} = cached_msg ->
        MessageCacheRepo.delete!(cached_msg)
        {:ok, message}

      _ ->
        nil
    end
  end

  @impl Nostrum.Cache.MessageCache
  def bulk_delete(channel_id, message_ids) do
    MessageCacheRepo.transaction(fn ->
      Enum.reduce(message_ids, [], fn message_id, acc ->
        case delete(channel_id, message_id) do
          nil ->
            acc

          message ->
            [message | acc]
        end
      end)
    end)
    |> case do
      {:ok, messages} ->
        Enum.reverse(messages)

      _ ->
        []
    end
  end

  @impl Nostrum.Cache.MessageCache
  def channel_delete(channel_id) do
    query = from(m in MessageSchema, where: m.channel_id == ^channel_id)
    MessageCacheRepo.delete_all(query)

    :ok
  end

  @impl Nostrum.Cache.MessageCache
  def get_by_channel(
        channel_id,
        after_timestamp \\ 0,
        before_timestamp \\ :infinity
      )

  def get_by_channel(channel_id, after_timestamp, :infinity) do
    after_timestamp = Nostrum.Util.timestamp_like_to_snowflake(after_timestamp)

    from(m in MessageSchema,
      where:
        m.channel_id == ^channel_id and
          m.id > ^after_timestamp,
      order_by: [asc: m.id]
    )
    |> MessageCacheRepo.all()
    |> Enum.map(& &1.data)
  end

  def get_by_channel(channel_id, after_timestamp, before_timestamp) do
    after_timestamp = Nostrum.Util.timestamp_like_to_snowflake(after_timestamp)
    before_timestamp = Nostrum.Util.timestamp_like_to_snowflake(before_timestamp)

    from(m in MessageSchema,
      where:
        m.channel_id == ^channel_id and
          m.id > ^after_timestamp and
          m.id < ^before_timestamp,
      order_by: [asc: m.id]
    )
    |> MessageCacheRepo.all()
    |> Enum.map(& &1.data)
  end

  @impl Nostrum.Cache.MessageCache
  def get_by_channel_and_author(
        channel_id,
        author_id,
        after_timestamp \\ 0,
        before_timestamp \\ :infinity
      )

  def get_by_channel_and_author(channel_id, author_id, after_timestamp, :infinity) do
    after_timestamp = Nostrum.Util.timestamp_like_to_snowflake(after_timestamp)

    from(m in MessageSchema,
      where:
        m.channel_id == ^channel_id and
          m.author_id == ^author_id and
          m.id > ^after_timestamp,
      order_by: [asc: m.id]
    )
    |> MessageCacheRepo.all()
    |> Enum.map(& &1.data)
  end

  def get_by_channel_and_author(channel_id, author_id, after_timestamp, before_timestamp) do
    after_timestamp = Nostrum.Util.timestamp_like_to_snowflake(after_timestamp)
    before_timestamp = Nostrum.Util.timestamp_like_to_snowflake(before_timestamp)

    from(m in MessageSchema,
      where:
        m.channel_id == ^channel_id and
          m.author_id == ^author_id and
          m.id > ^after_timestamp and
          m.id < ^before_timestamp,
      order_by: [asc: m.id]
    )
    |> MessageCacheRepo.all()
    |> Enum.map(& &1.data)
  end

  @impl Nostrum.Cache.MessageCache
  def get_by_author(
        arg0,
        after_timestamp \\ 0,
        before_timestamp \\ :infinity
      )

  def get_by_author(author_id, after_timestamp, :infinity) do
    after_timestamp = Nostrum.Util.timestamp_like_to_snowflake(after_timestamp)

    from(m in MessageSchema,
      where:
        m.author_id == ^author_id and
          m.id > ^after_timestamp,
      order_by: [asc: m.id]
    )
    |> MessageCacheRepo.all()
    |> Enum.map(& &1.data)
  end

  def get_by_author(author_id, after_timestamp, before_timestamp) do
    after_timestamp = Nostrum.Util.timestamp_like_to_snowflake(after_timestamp)
    before_timestamp = Nostrum.Util.timestamp_like_to_snowflake(before_timestamp)

    from(m in MessageSchema,
      where:
        m.author_id == ^author_id and
          m.id > ^after_timestamp and
          m.id < ^before_timestamp,
      order_by: [asc: m.id]
    )
    |> MessageCacheRepo.all()
    |> Enum.map(& &1.data)
  end
end
