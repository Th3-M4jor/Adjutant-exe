defmodule BnBBot do
  use Application

  def start(_type, _args) do
    BnBBot.RepoSupervisor.start_link([])
    BnBBot.Supervisor.start_link([])
  end
end
