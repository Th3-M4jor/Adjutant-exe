defmodule BnBBot do
  @moduledoc """
  Defines the Bot's "Application" for auto-startup
  """

  use Application

  def start(_type, _args) do
    children = [
      BnBBot.Supervisor,
      BnBBot.RepoSupervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
