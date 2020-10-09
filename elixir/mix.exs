defmodule RedisCrunchChallenge.MixProject do
  use Mix.Project

  def project do
    [
      app: :redis_crunch_challenge,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {RedisCrunchChallenge, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:gen_stage, "~> 1.0.0"},
      {:flow, "~> 1.0.0"},
      {:broadway, "~> 0.6.2"},
      {:jason, "~> 1.2"},
      {:nimble_csv, "~> 1.1"},
      {:redix, "~> 1.0"}
    ]
  end
end
