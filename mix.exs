defmodule ElixirBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_bot,
      version: "0.1.1",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        bnb_bot: [
          version: "0.1.1",
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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      #{:nostrum, "~> 0.4"},
      {:nostrum, git: "https://github.com/Kraigie/nostrum.git"},
      {:dotenv, "~> 3.1"},
      {:httpoison, "~> 1.7"},
      {:poison, "~> 3.0"},
      {:dialyxir, "~> 0.4", only: [:dev]}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
