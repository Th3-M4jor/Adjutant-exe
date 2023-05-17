defmodule BnBBot.PsychoEffects do
  @moduledoc """
  Module that holds all functions used for "troll" effects.
  """
  @random_effects [
    :resolve_role_effect,
    :resolve_timeout_effect,
    :resolve_shadowban_effect,
    :resolve_disconnect_effect,
    :resolve_troll_effect,
    :resolve_react_effect
  ]

  @troll_emojis :elixir_bot |> Application.compile_env!(:troll_emojis)

  alias Nostrum.Api
  alias Nostrum.Snowflake
  alias Nostrum.Struct.{Emoji, Message}

  require Logger

  # Slot 1 holds the unix time in seconds
  # of the last time a random effect was resolved
  @last_psycho_effect_time_key 1

  # Slot 2 holds the id of the user who got the effect
  @last_user_afflicted_key 2

  # Slot 3 holds the enum of the effect for the effected user
  # if the effect is one that happens over time
  @over_time_effect_key 3

  @over_time_effect_none 0
  @over_time_effect_shadowban 1
  @over_time_effect_troll 2
  @over_time_effect_react 3

  @spec maybe_resolve_random_effect(Message.t(), :atomics.atomics_ref()) :: :ignore
  def maybe_resolve_random_effect(%Message{} = msg, atomic_ref) do
    if should_resolve?(msg, atomic_ref) do
      Logger.info("Resolving random effect")
      Task.start(__MODULE__, :resolve_random_effect, [msg])
    end

    :ignore
  end

  @spec should_resolve?(Message.t(), :atomics.atomics_ref()) :: boolean()
  def should_resolve?(%Message{} = msg, ref) do
    Logger.debug("Checking if we should resolve a random effect")

    %{
      channel_id: channel_id,
      author: %{id: user_id},
      member: %{roles: roles}
    } = msg

    has_ranger_role = Enum.member?(roles, ranger_role_id())

    Logger.debug("Has ranger role: #{inspect(has_ranger_role)}")

    rand_chance = if channel_id == ranger_channel_id(), do: 100, else: 5_000

    has_ranger_role and not resolved_effect_recently?(user_id, ref) and
      :rand.uniform(rand_chance) == 1
  end

  @spec maybe_resolve_user_effect(Message.t(), :atomics.atomics_ref()) :: any()
  def maybe_resolve_user_effect(%Message{} = msg, ref) do
    over_time_effect = :atomics.get(ref, @over_time_effect_key)

    if over_time_effect == @over_time_effect_none, do: throw(:halt)

    %{id: message_id, channel_id: channel_id, author: %{id: user_id}} = msg

    last_user = :atomics.get(ref, @last_user_afflicted_key)

    unless last_user == user_id, do: throw(:halt)

    last_date_unix_seconds = :atomics.get(ref, @last_psycho_effect_time_key)
    now = System.os_time(:second)

    case over_time_effect do
      @over_time_effect_shadowban when now - last_date_unix_seconds >= 5 * 60 ->
        Task.start(fn -> shadowban(channel_id, message_id) end)

      @over_time_effect_troll when now - last_date_unix_seconds >= 10 * 60 ->
        Task.start(fn -> troll(channel_id, message_id) end)

      @over_time_effect_react when now - last_date_unix_seconds >= 15 * 60 ->
        Task.start(fn -> react(channel_id, message_id) end)

      _ ->
        # shouldn't resolve anything
        # attempt to set the effect to none to speed up the next check
        :atomics.compare_exchange(
          ref,
          @over_time_effect_key,
          over_time_effect,
          @over_time_effect_none
        )
    end
  catch
    :halt ->
      :ok
  end

  @spec resolve_random_effect(Message.t(), :atomics.atomics_ref()) :: :ok
  def resolve_random_effect(%Message{} = msg, ref) do
    Logger.debug("Selecting random effect")

    %{
      channel_id: channel_id,
      id: msg_id,
      author: %{id: author_id, username: author_username}
    } = msg

    now = System.os_time(:second)
    effect = Enum.random(@random_effects)

    Logger.debug("Selected effect: #{effect}")

    effect_enum_val =
      case effect do
        :resolve_shadowban_effect -> @over_time_effect_shadowban
        :resolve_troll_effect -> @over_time_effect_troll
        :resolve_react_effect -> @over_time_effect_react
        _ -> @over_time_effect_none
      end

    :atomics.put(ref, @last_psycho_effect_time_key, now)
    :atomics.put(ref, @last_user_afflicted_key, author_id)
    :atomics.put(ref, @over_time_effect_key, effect_enum_val)

    Logger.debug("Sending message about resolving effect")

    Api.create_message!(channel_id, %{
      content: "Resolve all psycho effects!",
      message_reference: %{
        message_id: msg_id
      }
    })

    Logger.info("Resolving random effect: #{effect} on #{author_username}")

    apply(__MODULE__, effect, [msg, ref])
    :ok
  rescue
    e ->
      Logger.error(Exception.format(:error, e, __STACKTRACE__))

      Api.create_message(
        msg.channel_id,
        "An error has occurred, inform Major\n#{Exception.message(e)}"
      )

      :ok
  end

  def resolve_role_effect(%Message{} = msg, _ref) do
    roles = Application.get_env(:elixir_bot, :roles)
    role_ids = Enum.map(roles, fn role -> role.id end)

    Enum.each(role_ids, fn role_id ->
      Api.remove_guild_member_role(
        msg.guild_id,
        msg.author.id,
        role_id,
        "Resolve all psycho effects!"
      )
    end)
  end

  def resolve_timeout_effect(%Message{} = msg, ref) do
    guild_id = msg.guild_id
    user_id = msg.author.id
    muted_until = DateTime.utc_now() |> DateTime.add(10 * 60) |> DateTime.to_iso8601()

    Api.modify_guild_member(
      guild_id,
      user_id,
      %{communication_disabled_until: muted_until},
      "Resolve all psycho effects!"
    )
    |> case do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        :atomics.put(ref, @over_time_effect_key, @over_time_effect_shadowban)
        Logger.error("Failed to mute user: #{inspect(reason)}, shadow banning instead")
    end
  end

  # This is a no-op since this is an async effect
  def resolve_shadowban_effect(_msg, _ref) do
    :ok
  end

  # This is a no-op since this is an async effect
  def resolve_troll_effect(_msg, _ref) do
    :ok
  end

  # This is a no-op since this is an async effect
  def resolve_react_effect(_msg, _ref) do
    :ok
  end

  def resolve_disconnect_effect(%Message{} = msg, ref) do
    voice_states = Nostrum.Cache.GuildCache.get!(msg.guild_id).voice_states

    with true <-
           Enum.any?(voice_states, fn voice_state -> voice_state.user_id == msg.author.id end),
         {:ok, _} <-
           Api.modify_guild_member(
             msg.guild_id,
             msg.author.id,
             %{channel_id: nil},
             "Resolve all psycho effects!"
           ) do
      :ok
    else
      _ ->
        resolve_timeout_effect(msg, ref)
    end
  end

  def shadowban(channel_id, message_id) do
    Api.delete_message(channel_id, message_id)
  end

  def troll(channel_id, message_id) do
    if :rand.uniform(2) == 1 do
      troll_msg = BnBBot.PsychoEffects.Insults.get_random()

      Api.create_message(channel_id, %{
        content: troll_msg.insult,
        message_reference: %{
          message_id: message_id
        }
      })
    end
  end

  def react(channel_id, message_id) do
    emoji =
      case Enum.random(@troll_emojis) do
        {name, id} ->
          %Emoji{
            name: name,
            id: id
          }

        {name, id, animated} ->
          %Emoji{
            name: name,
            id: id,
            animated: animated
          }

        emoji when is_binary(emoji) ->
          emoji
      end

    Api.create_reaction(channel_id, message_id, emoji)
  end

  @spec resolved_effect_recently?(Snowflake.t(), :atomics.atomics_ref()) :: boolean()
  defp resolved_effect_recently?(author_id, ref) do
    # last_psycho = GenServer.call(:bnb_bot_data, {:get, :last_psycho})

    Logger.debug("Checking if #{author_id} has been psycho'd recently")

    last_date_unix_seconds = :atomics.get(ref, @last_psycho_effect_time_key)

    Logger.debug("Last psycho effect time in unix seconds: #{last_date_unix_seconds}")

    last_user = :atomics.get(ref, @last_user_afflicted_key)

    Logger.debug("Last user afflicted: #{last_user}")

    now = System.os_time(:second)

    recently =
      if author_id == last_user do
        # If the user has been psycho'd in the last hour, don't psycho them again
        last_date_unix_seconds + 60 * 60 * 2 >= now
      else
        # else different user, 20 minutes is long enough
        last_date_unix_seconds + 20 * 60 >= now
      end

    Logger.debug("Recently psycho'd: #{recently}")

    recently
  end

  defp ranger_channel_id do
    Application.get_env(:elixir_bot, :ranger_channel_id)
  end

  defp ranger_role_id do
    Application.get_env(:elixir_bot, :ranger_role_id)
  end
end
