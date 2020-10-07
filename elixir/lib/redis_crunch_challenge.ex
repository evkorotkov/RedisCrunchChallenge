defmodule RedisCrunchChallenge do
  use Application

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    IO.puts "Started"

    Supervisor.start_link(children(), strategy: :one_for_one, name: RedisCrunchChallenge.Supervisor)
  end

  defp children do
    case app_mode() do
      :genstage -> [{RedisCrunchChallenge.GenStage.Supervisor, restart: :transient, shutdown: 1000}]
      :flow -> [{RedisCrunchChallenge.Flow, [list_name: "events_queue"]}]
      :broadway -> [{RedisCrunchChallenge.Broadway, []}]
      _ -> []
    end
  end

  defp app_mode do
    Application.get_env(:redis_crunch_challenge, :mode, :unknown)
  end
end
