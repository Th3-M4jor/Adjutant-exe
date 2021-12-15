defmodule BnBBot.Util do
  alias Nostrum.Api
  require Logger

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

  @spec get_user_perms(Nostrum.Struct.Message.t() | Nostrum.Struct.Interaction.t()) ::
          :admin | :everyone | :owner
  def get_user_perms(msg) do
    cond do
      is_owner_msg?(msg) -> :owner
      is_admin_msg?(msg) -> :admin
      true -> :everyone
    end
  end

  @spec is_owner_msg?(Nostrum.Struct.Message.t() | Nostrum.Struct.Interaction.t()) :: boolean
  def is_owner_msg?(%Nostrum.Struct.Message{} = msg) do
    {:ok, owner_id} = Nostrum.Snowflake.cast(Application.fetch_env!(:elixir_bot, :owner_id))
    {:ok, msg_author_id} = Nostrum.Snowflake.cast(msg.author.id)
    owner_id == msg_author_id
  end

  def is_owner_msg?(%Nostrum.Struct.Interaction{} = inter) do
    {:ok, owner_id} = Nostrum.Snowflake.cast(Application.fetch_env!(:elixir_bot, :owner_id))

    inter_author_id =
      if is_nil(inter.member) do
        inter.user.id
      else
        inter.member.user.id
      end
      |> Nostrum.Snowflake.cast!()

    owner_id == inter_author_id
  end

  @spec is_admin_msg?(Nostrum.Struct.Message.t() | Nostrum.Struct.Interaction.t()) :: boolean
  def is_admin_msg?(%Nostrum.Struct.Message{} = msg) do
    admins = Application.fetch_env!(:elixir_bot, :admins)
    Enum.any?(admins, fn id -> id == msg.author.id end)
  end

  def is_admin_msg?(%Nostrum.Struct.Interaction{} = inter) do
    admins = Application.fetch_env!(:elixir_bot, :admins)

    inter_author_id =
      if is_nil(inter.member) do
        inter.user.id
      else
        inter.member.user.id
      end
      |> Nostrum.Snowflake.cast!()

    Enum.any?(admins, fn id -> id == inter_author_id end)
  end

  @spec dm_owner(keyword() | map() | String.t(), boolean()) ::
          {:ok, Nostrum.Struct.Message.t()} | :error | nil
  def dm_owner(to_say, override \\ false) do
    res =
      case :ets.lookup(:bnb_bot_data, :dm_owner) do
        [dm_owner: val] -> val
        _ -> true
      end

    if res or override do
      {:ok, owner_id} =
        Application.fetch_env!(:elixir_bot, :owner_id)
        |> Nostrum.Snowflake.cast()

      dm_channel_id = find_dm_channel_id(owner_id)
      Api.create_message(dm_channel_id, to_say)
    end
  end

  @doc """
  Finds the id of a the DM channel for a user, or fetches it from the API if its not in the cache
  """
  @spec find_dm_channel_id(Nostrum.Snowflake.t()) :: Nostrum.Snowflake.t()
  def find_dm_channel_id(user_id) do
    # get the channel_id where it's first recipient's.id == user_id
    dm_channel_list =
      :ets.select(:channels, [
        {{:"$1", %{recipients: [%{id: :"$2"}]}}, [{:==, user_id, :"$2"}], [:"$1"]}
      ])

    case dm_channel_list do
      [id | _] ->
        id

      _ ->
        {:ok, channel} = Api.create_dm(user_id)
        channel.id
    end
  end
end
