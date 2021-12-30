defmodule BnBBot do
  @moduledoc """
  Defines the Bot's "Application" for auto-startup
  """

  use Application

  def start(_type, _args) do
    BnBBot.RepoSupervisor.start_link([])
    BnBBot.Supervisor.start_link([])
  end
end
