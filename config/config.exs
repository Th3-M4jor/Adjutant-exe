import Config

config :logger, :default_formatter,
  format: "\n$date $time $metadata[$level] $message\n",
  metadata: [:pid]

config :adjutant, :logger, [
    {:handler, :file_log, :logger_disk_log_h,
     %{
       config: %{
         file: ~c"log/adjutant_#{config_env()}.log"
       },
       formatter:
         Logger.Formatter.new(
           format: "\n$date $time $metadata[$level] $message\n",
           metadata: [:pid]
         )
     }}
  ]

import_config "#{config_env()}.exs"
