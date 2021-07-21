#rename this file to "config.exs", replace the token and it'll run
import Config

config :nostrum,
  # The token of your bot as a string
  token: "token_here",
  # The number of shards you want to run your bot under, or :auto.
  num_shards: 1,
  gateway_intents: [
    :direct_messages,
    :guild_bans,
    :guild_members,
    :guild_message_reactions,
    :guild_messages,
    :guilds
  ]

# config :logger,
#  level: :warn

config :elixir_bot,
  prefix: "!",
  ready_channel: 681_526_530_987_524_144
