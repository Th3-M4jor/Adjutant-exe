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
  alias Nostrum.Struct.{Emoji, Message}

  require Logger

  @spec maybe_resolve_random_effect(Message.t()) :: :ignore
  def maybe_resolve_random_effect(%Message{} = msg) do
    if should_resolve?(msg) do
      Task.start(__MODULE__, :resolve_random_effect, [msg])
    end

    :ignore
  end

  @spec should_resolve?(Message.t()) :: boolean()
  def should_resolve?(%Message{} = msg) do
    msg.channel_id == ranger_channel_id() and
      :rand.uniform(100) == 1 and not resolved_effect_recently?(msg.author.id)
  end

  def maybe_resolve_user_effect(%Message{id: message_id, channel_id: channel_id} = msg) do
    case get_user_effect(msg.guild_id, msg.author.id) do
      :shadowban ->
        Task.start(fn -> shadowban(channel_id, message_id) end)

      :troll ->
        Task.start(fn -> troll(channel_id, message_id) end)

      :react ->
        Task.start(fn -> react(channel_id, message_id) end)

      nil ->
        # user has no effect do nothing
        nil
    end
  end

  @spec resolve_random_effect(Message.t()) :: :ok
  def resolve_random_effect(%Message{channel_id: channel_id, id: msg_id} = msg) do
    Api.create_message!(channel_id, %{
      content: "Resolve all psycho effects!",
      message_reference: %{
        message_id: msg_id
      }
    })

    effect = Enum.random(@random_effects)
    Logger.info("Resolving random effect: #{effect} on #{msg.author.username}")
    GenServer.cast(:bnb_bot_data, {:insert, :last_psycho, {DateTime.utc_now(), msg.author.id}})
    apply(__MODULE__, effect, [msg])
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

  def resolve_role_effect(%Message{} = msg) do
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

  def resolve_timeout_effect(%Message{} = msg) do
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
        Logger.error("Failed to mute user: #{inspect(reason)}, shadow banning instead")
        resolve_shadowban_effect(msg)
    end
  end

  def resolve_shadowban_effect(%Message{} = msg) do
    psycho_tuple = {:psycho, msg.guild_id, msg.author.id}
    GenServer.cast(:bnb_bot_data, {:insert, psycho_tuple, :shadowban})

    Process.sleep(:timer.seconds(5 * 60))

    GenServer.cast(:bnb_bot_data, {:delete, psycho_tuple})
  end

  def resolve_troll_effect(%Message{} = msg) do
    psycho_tuple = {:psycho, msg.guild_id, msg.author.id}
    GenServer.cast(:bnb_bot_data, {:insert, psycho_tuple, :troll})

    Process.sleep(:timer.seconds(10 * 60))

    GenServer.cast(:bnb_bot_data, {:delete, psycho_tuple})
  end

  def resolve_react_effect(%Message{} = msg) do
    psycho_tuple = {:psycho, msg.guild_id, msg.author.id}
    GenServer.cast(:bnb_bot_data, {:insert, psycho_tuple, :react})

    Process.sleep(:timer.seconds(10 * 60))

    GenServer.cast(:bnb_bot_data, {:delete, psycho_tuple})
  end

  def resolve_disconnect_effect(%Message{} = msg) do
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
        resolve_timeout_effect(msg)
    end
  end

  def get_user_effect(guild_id, user_id) do
    GenServer.call(:bnb_bot_data, {:get, {:psycho, guild_id, user_id}})
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

  defp resolved_effect_recently?(msg_author_id) do
    last_psycho = GenServer.call(:bnb_bot_data, {:get, :last_psycho})

    case last_psycho do
      nil ->
        false

      {%DateTime{} = last_psycho, user_id} when user_id == msg_author_id ->
        # If the user has been psycho'd in the last hour, don't psycho them again
        DateTime.diff(DateTime.utc_now(), last_psycho) < 60 * 60 * 2

      {%DateTime{} = last_psycho, _user_id} ->
        # else different user, don't care, 20 minutes is long enough
        DateTime.diff(DateTime.utc_now(), last_psycho) < 20 * 60
    end
  end

  defp ranger_channel_id do
    Application.get_env(:elixir_bot, :ranger_channel_id)
  end
end
