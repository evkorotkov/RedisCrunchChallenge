use Mix.Config

config :redis_crunch_challenge, :redis,
  host: System.get_env("REDIS_HOST") || "redis",
  port: System.get_env("REDIS_PORT") || 6379

output_dir = ["/scripts", "output", "elixir"] |> Path.join() |> Path.expand()
config :redis_crunch_challenge, :output_dir, output_dir
