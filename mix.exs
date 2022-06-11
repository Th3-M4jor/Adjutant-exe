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
          cookie: get_cookie()
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
      # {:nostrum, "~> 0.6"},
      {:nostrum, git: "https://github.com/Th3-M4jor/nostrum.git"},
      # {:nostrum, path: "../nostrum/"},
      {:jason, "~> 1.2"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.15.10"},
      {:ecto_sqlite3, "~> 0.7.1"},
      {:oban, "~> 2.12"},
      {:ex2ms, "~> 1.6"},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
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
