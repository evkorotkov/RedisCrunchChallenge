defmodule RedisCrunchChallenge do
  use Application

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    IO.puts "Started"

    Supervisor.start_link(children(), strategy: :one_for_one, name: RedisCrunchChallenge.Supervisor)
  end

  defp children do
    import Supervisor.Spec, warn: false

    case app_mode() do
      :gen_server -> [supervisor(RedisCrunchChallenge.GenServer.Supervisor, [], restart: :transient, shutdown: 500)]
      :gen_stage -> [supervisor(RedisCrunchChallenge.GenStage.Supervisor, [], restart: :transient, shutdown: 500)]
      :flow -> [{RedisCrunchChallenge.Flow, [list_name: "events_queue"]}]
      :broadway -> [{RedisCrunchChallenge.Broadway, []}]
      _ -> []
    end
  end

  defp app_mode do
    Application.get_env(:redis_crunch_challenge, :mode, :unknown)
  end
end
