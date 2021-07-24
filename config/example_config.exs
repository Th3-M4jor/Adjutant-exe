# rename this file to "config.exs", replace the token and it'll run
# however it's recommended to have a "dev.exs" and a "prod.exs"
# where the "config.exs" only does `import_config "#{config_env()}.exs"`
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

  config :logger,
  level: :warn,
  compile_time_purge_matching: [
    [module: Nostrum, level_lower_than: :warn],
    [module: Nostrum.Api, level_lower_than: :warn],
    [module: Nostrum.Application, level_lower_than: :warn],
    [module: Nostrum.Shard.Dispatch, level_lower_than: :warn],
    [module: Nostrum.Shard.Event, level_lower_than: :warn]
  ]

config :elixir_bot,
  prefix: "!",
  owner_id: 666,
  admins: [667, 668]
