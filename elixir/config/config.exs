use Mix.Config

config :redis_crunch_challenge, :redis,
  host: System.get_env("REDIS_HOST") || "127.0.0.1",
  port: System.get_env("REDIS_PORT") || 6379

output_file_name = [File.cwd!(), "../", "output", "elixir"] |> Path.join() |> Path.expand()
config :redis_crunch_challenge, :output_file_name, output_file_name
