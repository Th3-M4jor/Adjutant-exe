defmodule Adjutant.BotSupervisor do
  @moduledoc """
  Main entry point for the bot.
  """

  require Logger
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.debug("Starting Supervisor")

    Adjutant.Telemetry.init()

    button_collector = Registry.child_spec(keys: :unique, name: :BUTTON_COLLECTOR)

    children = [
      button_collector,
      {Nostrum.Bot, {bot_config(), [strategy: :one_for_one]}}
    ]

    res = Supervisor.init(children, strategy: :one_for_one)
    Logger.debug("Supervisor started")
    # :ignore
    res
  end

  defp bot_config do
    token = Application.fetch_env!(:adjutant, :token)
    intents = Application.fetch_env!(:adjutant, :gateway_intents)

    %{
      name: :adjutant,
      consumer: Adjutant.Consumer,
      intents: intents,
      wrapped_token: fn -> token end
    }
  end
end
