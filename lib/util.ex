defmodule BnBBot.Util do
  alias Nostrum.Api
  require Logger

  @spec react(Nostrum.Struct.Message.t(), boolean | String.t()) :: any()
  def react(msg, emote \\ "\u{1F44D}")

  def react(%Nostrum.Struct.Message{} = msg, true) do
    Logger.debug("Reacting with \u{2705}")
    Api.create_reaction(msg.channel_id, msg.id, "\u{2705}")
  end

  def react(%Nostrum.Struct.Message{} = msg, false) do
    Logger.debug("Reacting with \u{274E}")
    Api.create_reaction(msg.channel_id, msg.id, "\u{274E}")
  end

  def react(%Nostrum.Struct.Message{} = msg, emote) do
    Logger.debug("Reacting with #{emote}")
    Api.create_reaction(msg.channel_id, msg.id, emote)
  end

  @spec is_owner_msg?(Nostrum.Struct.Message.t()) :: boolean
  def is_owner_msg?(%Nostrum.Struct.Message{} = msg) do
    {:ok, owner_id} = Nostrum.Snowflake.cast(Application.fetch_env!(:elixir_bot, :owner_id))
    {:ok, msg_author_id} = Nostrum.Snowflake.cast(msg.author.id)
    owner_id == msg_author_id
  end

  def find_dm_channel(user_id) do
    dm_channels = :ets.tab2list(:channels)

    chn =
      Enum.find(dm_channels, nil, fn {_, chn} ->
        Enum.any?(chn.recipients, fn r -> r.id == user_id end)
      end)

    if is_nil(chn) do
      Api.create_dm!(user_id)
    else
      {_, chn} = chn
      chn
    end
  end
end
