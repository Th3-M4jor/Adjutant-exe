defmodule BnBBot.Util do
  @moduledoc """
  Various internal utility functions
  """

  alias Nostrum.Api
  import Nostrum.Snowflake, only: [is_snowflake: 1]
  require Logger

  @owner_id :elixir_bot |> Application.compile_env!(:owner_id)
  @admins :elixir_bot |> Application.compile_env!(:admins)

  @doc """
  React to a message with a given unicode emoji, if a boolean is given instead
  then it will react with thumbs up or down
  """
  @spec react(Nostrum.Struct.Message.t(), boolean | String.t()) :: any()
  def react(msg, emote \\ "\u{1F44D}")

  def react(%Nostrum.Struct.Message{channel_id: channel_id, id: msg_id}, true) do
    Logger.debug("Reacting with \u{2705}")
    Api.create_reaction(channel_id, msg_id, "\u{2705}")
  end

  def react(%Nostrum.Struct.Message{channel_id: channel_id, id: msg_id}, false) do
    Logger.debug("Reacting with \u{274E}")
    Api.create_reaction(channel_id, msg_id, "\u{274E}")
  end

  def react(%Nostrum.Struct.Message{channel_id: channel_id, id: msg_id}, emote) do
    Logger.debug("Reacting with #{emote}")
    Api.create_reaction(channel_id, msg_id, emote)
  end

  @doc """
  Check if a message is from the owner or an admin
  """
  @spec get_user_perms(Nostrum.Struct.Message.t() | Nostrum.Struct.Interaction.t()) ::
          :admin | :everyone | :owner
  def get_user_perms(msg) do
    cond do
      is_owner_msg?(msg) -> :owner
      is_admin_msg?(msg) -> :admin
      true -> :everyone
    end
  end

  @doc """
  Check if a message or interaction is from the owner
  """
  @spec is_owner_msg?(Nostrum.Struct.Message.t() | Nostrum.Struct.Interaction.t()) :: boolean
  def is_owner_msg?(%Nostrum.Struct.Message{} = msg) do
    owner_id = Nostrum.Snowflake.cast!(@owner_id)
    msg_author_id = Nostrum.Snowflake.cast!(msg.author.id)
    owner_id == msg_author_id
  end

  def is_owner_msg?(%Nostrum.Struct.Interaction{} = inter) do
    owner_id = Nostrum.Snowflake.cast!(@owner_id)

    inter_author_id =
      if is_nil(inter.member) do
        inter.user.id
      else
        inter.member.user.id
      end
      |> Nostrum.Snowflake.cast!()

    owner_id == inter_author_id
  end

  @doc """
  Check if a message or interaction is from an admin
  """
  @spec is_admin_msg?(Nostrum.Struct.Message.t() | Nostrum.Struct.Interaction.t()) :: boolean
  def is_admin_msg?(%Nostrum.Struct.Message{} = msg) do
    Enum.any?(@admins, fn id -> id == msg.author.id end)
  end

  def is_admin_msg?(%Nostrum.Struct.Interaction{} = inter) do
    inter_author_id =
      if is_nil(inter.member) do
        inter.user.id
      else
        inter.member.user.id
      end
      |> Nostrum.Snowflake.cast!()

    Enum.any?(@admins, fn id -> id == inter_author_id end)
  end

  @doc """
  Send a DM to the owner, second argument is for if this should override a do not DM setting
  """
  @spec dm_owner(keyword() | map() | String.t(), boolean()) ::
          {:ok, Nostrum.Struct.Message.t()} | :error | nil
  def dm_owner(to_say, override \\ false) do
    res =
      case GenServer.call(:bnb_bot_data, {:get, :dm_owner}) do
        nil -> true
        val when is_boolean(val) -> val
      end

    if res or override do
      owner_id = @owner_id |> Nostrum.Snowflake.cast!()

      dm_channel_id = find_dm_channel_id(owner_id)
      Api.create_message(dm_channel_id, to_say)
    end
  end

  @doc """
  Finds the id of a the DM channel for a user, or fetches it from the API if its not in the cache
  """
  @spec find_dm_channel_id(Nostrum.Snowflake.t()) :: Nostrum.Snowflake.t()
  def find_dm_channel_id(user_id) when is_snowflake(user_id) do
    # get the channel_id where it's first recipient's.id == user_id
    dm_channel_list =
      :ets.select(
        :nostrum_channels,
        [{{:"$1", %{recipients: [%{id: :"$2"}]}}, [{:==, :"$2", user_id}], [:"$1"]}]
      )

    case dm_channel_list do
      [id | _] ->
        id

      _ ->
        channel = Api.create_dm!(user_id)
        channel.id
    end
  end

  def slash_args_to_map([%{type: 1, name: name, options: options}]) do
    opts = slash_args_to_map(options)
    {name, opts}
  end

  def slash_args_to_map(options) do
    for %{name: name, value: value} <- options, into: %{} do
      {name, value}
    end
  end
end

defmodule BnBBot.Util.KVP do
  @moduledoc """
  Module for handling internal global state.
  Slower than using an ets table, but much more memory efficient
  """

  require Logger
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: :bnb_bot_data)
  end

  def init(initial_state) when is_map(initial_state) do
    {:ok, initial_state}
  end

  def init(_initial_state) do
    Logger.warn("Initial state is not a map, using empty map")
    {:ok, %{}}
  end

  def handle_cast({:insert, key, value}, state) do
    state = Map.put(state, key, value)
    {:noreply, state}
  end

  def handle_cast({:delete, key}, state) do
    state = Map.delete(state, key)
    {:noreply, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end
end

defmodule BnBBot.Util.MessageEditWorker do
  @moduledoc """
  Oban worker for handling scheduled message edits
  """
  @queue_name :elixir_bot |> Application.compile_env!(:edit_message_queue)

  require Logger

  alias Nostrum.Api

  use Oban.Worker, queue: @queue_name

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "channel_id" => channel_id,
          "message_id" => message_id,
          "content" => content,
          "components" => components
        }
      }) do
    channel_id = channel_id |> Nostrum.Snowflake.cast!()
    message_id = message_id |> Nostrum.Snowflake.cast!()

    Api.edit_message(channel_id, message_id, %{
      content: content,
      components: components
    })
    |> case do
      {:ok, _} ->
        :ok

      {:error, err} ->
        Logger.warn("Error editing message: #{err}")
        {:error, err}
    end
  end

  def perform(%Oban.Job{
        args: %{"channel_id" => channel_id, "message_id" => message_id, "content" => content}
      }) do
    channel_id = channel_id |> Nostrum.Snowflake.cast!()
    message_id = message_id |> Nostrum.Snowflake.cast!()

    Api.edit_message(channel_id, message_id, %{
      content: content
    })
    |> case do
      {:ok, _} ->
        :ok

      {:error, err} ->
        Logger.warn("Error editing message: #{err}")
        {:error, err}
    end
  end
end
