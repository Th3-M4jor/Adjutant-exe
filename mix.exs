defmodule ElixirBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :adjutant,
      version: "0.1.9",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        adjutant: [
          version: "0.4.0",
          applications: [
            adjutant: :permanent
          ],
          cookie: get_cookie()
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Adjutant.Application, []},
      extra_applications: [:logger, :runtime_tools, :mnesia]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:nostrum,
      #  git: "https://github.com/kyleboe/nostrum.git",
      #  ref: "d4058b83935586aba1831cfd856dfda340b2a719"},
      # {:nostrum, "~> 0.10"},
      {:nostrum, path: "../nostrum"},
      {:telemetry, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:ecto_sql, "~> 3.0"},
      {:ecto_sqlite3, "~> 0.15"},
      {:oban, "~> 2.12"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp get_cookie do
    case File.read("COOKIE") do
      {:ok, cookie} ->
        cookie

      {:error, _err} ->
        unless Mix.env() == :test do
          IO.warn(
            "Could not read COOKIE file, using default cookie. Not recommended for production."
          )
        end

        "SOME_COOKIE"
    end
  end
end
