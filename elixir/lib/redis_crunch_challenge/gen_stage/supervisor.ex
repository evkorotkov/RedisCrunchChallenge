defmodule RedisCrunchChallenge.GenStage.Supervisor do
  use Supervisor

  alias RedisCrunchChallenge.GenStage.Producer
  alias RedisCrunchChallenge.GenStage.Consumer

  @producers_count 10
  @consumers_per_producer 5

  def start_link(opts) do
    IO.puts "Processing GenStage"

    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    producers = producers_spec(@producers_count)
    consumers = consumers_spec(@producers_count, @consumers_per_producer)

    children = producers ++ consumers

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp producers_spec(count \\ 1) do
    Enum.map(1..count, fn id ->
      name = String.to_atom("prod#{id}")

      Supervisor.child_spec(
        {Producer, [name: name, list_name: "events_queue"]},
        id: name,
        shutdown: 1000,
        restart: :transient
      )
    end)
  end

  defp consumers_spec(producers_count \\ 1, per_producer \\ 2) do
    output_file = output_file()

    Enum.flat_map(1..producers_count, fn producer_id ->
      prod_name = String.to_existing_atom("prod#{producer_id}")

      Enum.map(1..per_producer, fn id ->
        name = String.to_atom("cons#{id}_#{producer_id}")

        Supervisor.child_spec(
          {Consumer, [name: name, producer: prod_name, output_file: output_file]},
          id: name,
          shutdown: 1000,
          restart: :transient
        )
      end)
    end)
  end

  defp output_file do
    RedisCrunchChallenge.CsvWriter.output_file()
  end
end
