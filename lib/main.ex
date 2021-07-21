defmodule BnBBot do
  use Application

  def start(_type, _args) do
    BnBBot.Supervisor.start_link([])
  end
end
