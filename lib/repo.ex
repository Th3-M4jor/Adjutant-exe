defmodule BnBBot.RepoSupervisor do
  @moduledoc """
  Supervises the sqlite and postgres repo.
  """
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      BnBBot.Repo.SQLite,
      BnBBot.Repo.Postgres,
      {Oban, oban_config()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp oban_config do
    Application.fetch_env!(:elixir_bot, Oban)
  end
end

defmodule BnBBot.Repo.SQLite do
  @moduledoc """
  The sqlite repo.
  """
  use Ecto.Repo, otp_app: :elixir_bot, adapter: Ecto.Adapters.SQLite3
end

defmodule BnBBot.Repo.Postgres do
  @moduledoc """
  The postgres repo.
  """
  use Ecto.Repo, otp_app: :elixir_bot, adapter: Ecto.Adapters.Postgres, read_only: true
end

defmodule BnBBot.CustomQuery do
  @moduledoc """
  Defines custom query methods, this is specific to postgres.
  """

  defmacro array_contains(array, value) do
    quote do
      fragment("? = ANY(?)", unquote(value), unquote(array))
    end
  end

  defmacro word_similarity(column, word) do
    quote do
      fragment("word_similarity(?, ?)", unquote(column), unquote(word))
    end
  end

  defmacro blight_elem_access(column) do
    quote do
      fragment("(?).elem", unquote(column))
    end
  end

  defmacro dienum_access(column) do
    quote do
      fragment("(?).dienum", unquote(column))
    end
  end

  defmacro dietype_access(column) do
    quote do
      fragment("(?).dietype", unquote(column))
    end
  end

  defmacro die_average(column) do
    quote do
      fragment("die_average(?)", unquote(column))
    end
  end
end
