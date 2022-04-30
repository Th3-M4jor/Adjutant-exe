# rename this file to "config.exs", replace the token and it'll run
# however it's recommended to have a "dev.exs" and a "prod.exs"
# where the "config.exs" only does `import_config "#{config_env()}.exs"`
import Config

config :nostrum,
  # The token of your bot as a string
  token: "token_here",
  # The number of shards you want to run your bot under, or :auto.
  num_shards: :auto,
  gateway_intents: [
    :direct_messages,
    :guild_bans,
    :guild_members,
    :guild_message_reactions,
    :guild_messages,
    :guilds
  ]

config :logger,
  level: :info,
  backends: [
    :console,
    {BnBBot.LogBackend, :log_backend}
  ],
  compile_time_purge_matching: [
    [module: Nostrum, level_lower_than: :warn],
    [module: Nostrum.Api, level_lower_than: :warn],
    [module: Nostrum.Application, level_lower_than: :warn],
    [module: Nostrum.Shard.Dispatch, level_lower_than: :warn],
    [module: Nostrum.Shard.Event, level_lower_than: :warn]
  ]

config :elixir_bot, Oban,
  prefix: "oban_jobs",
  repo: BnBBot.Repo.Postgres,
  queues: [dev_remind_me: [limit: 2, paused: true]]

# uses sqlite for logging
config :elixir_bot, BnBBot.Repo.SQLite,
  database: "./db/dev_db.db",
  priv: "priv/sqlite"

# uses postgres for storing BnB data, and for Oban
config :elixir_bot, BnBBot.Repo.Postgres,
  username: "postgres",
  password: "postgres",
  database: "default",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  priv: "priv/postgres"

config :elixir_bot,
  ecto_repos: [BnBBot.Repo.SQLite, BnBBot.Repo.Postgres],
  ecto_shard_count: 1,
  prefix: "!",
  owner_id: 666,
  admins: [667, 668],
  dm_log_id: 999,
  primary_guild_id: 555,
  primary_guild_channel_id: 12_354_456_457_567,
  primary_guild_role_channel_id: 669,
  backend_node_name: :foo@bar,
  webhook_node_name: :baz@bar,
  ncp_url: "https://jin-tengai.dev/bnb/backend/fetch/ncps",
  chip_url: "https://jin-tengai.dev/bnb/backend/fetch/chips",
  virus_url: "https://jin-tengai.dev/bnb/backend/fetch/viruses",
  phb_links: [
    %{
      type: 2,
      style: 5,
      label: "B&B PHB",
      url: "https://jin-tengai.dev/bnb/#!/home"
    },
    %{
      type: 2,
      style: 5,
      label: "Manager",
      url: "https://jin-tengai.dev/manager"
    }
  ],
  ncp_emoji: %{
    white: %{
      id: nil,
      name: "\u{2B1C}"
    },
    pink: %{
      id: "912046716767830036",
      name: "pink_square"
    },
    yellow: %{
      id: nil,
      name: "\u{1F7E8}"
    },
    green: %{
      id: nil,
      name: "\u{1F7E9}"
    },
    blue: %{
      id: nil,
      name: "\u{1F7E6}"
    },
    red: %{
      id: nil,
      name: "\u{1F7E5}"
    },
    gray: %{
      id: "912054778421448705",
      name: "gray_square"
    }
    # id: nil,

    # jigsaw emoji
    # name: "\u{1F9E9}"
  },
  virus_emoji: %{
    id: nil,

    # space invader emoji
    name: "\u{1F47E}"
  },
  chip_emoji: %{
    id: "695852335943122974",
    name: "SynchroChip"
  },
  roles: [
    %{
      id: "579769580441042945",
      name: "Role Name",
      emoji: %{
        id: "695852335943122974",
        name: "SynchroChip"
      },
      style: 1
    }
  ]
