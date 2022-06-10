defmodule ElixirBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_bot,
      version: "0.1.3",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        bnb_bot: [
          version: "0.2.3",
          applications: [
            elixir_bot: :permanent
          ],
          cookie: File.read!("COOKIE")
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {BnBBot, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:nostrum, "~> 0.4"},
      # {:nostrum, git: "https://github.com/Kraigie/nostrum.git"},
      {:nostrum, path: "../nostrum/"},
      {:dotenv, "~> 3.1"},
      {:jason, "~> 1.2"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.15.10"},
      {:ecto_sqlite3, "~> 0.7.1"},
      {:oban, "~> 2.12"},
      {:ex2ms, "~> 1.6"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
