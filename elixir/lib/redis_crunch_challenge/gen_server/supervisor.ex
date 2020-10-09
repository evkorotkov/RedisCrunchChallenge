defmodule RedisCrunchChallenge.GenServer.Supervisor do
  use Supervisor

  alias RedisCrunchChallenge.DataSource
  alias RedisCrunchChallenge.GenServer.Worker

  @workers_count 60

  def start_link(opts \\ []) do
    IO.puts "Processing GenServer"

    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {Redix, DataSource.redis_config() ++ [name: :redix]}
    ] ++ workers_spec(@workers_count)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp workers_spec(count \\ 1) do
    output_file = output_file()

    Enum.map(1..count, fn id ->
      name = String.to_atom("worker_#{id}")

      Supervisor.child_spec(
        {Worker, [name: name, list_name: "events_queue", file_name: output_file]},
        id: name,
        shutdown: 1000,
        restart: :transient
      )
    end)
  end

  defp output_file do
    RedisCrunchChallenge.CsvWriter.output_file()
  end
end
