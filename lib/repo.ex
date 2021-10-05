defmodule BnBBot.RepoSupervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Supervisor.init([BnBBot.Repo], strategy: :one_for_one)
  end
end

defmodule BnBBot.Repo do
  use Ecto.Repo, otp_app: :elixir_bot, adapter: Ecto.Adapters.SQLite3
end
