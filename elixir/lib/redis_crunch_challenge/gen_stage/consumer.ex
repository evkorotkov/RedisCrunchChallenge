defmodule RedisCrunchChallenge.GenStage.Consumer do
  alias RedisCrunchChallenge.CsvWriter
  import RedisCrunchChallenge.CoreProcessor

  use GenStage

  @max_demand 500
  @min_demand 250

  def start_link(name: name, producer: producer, output_file: output_file) do
    GenStage.start_link(__MODULE__, {output_file, producer}, name: name)
  end

  def init({output_file, producer}) do
    define_supported_atoms()

    {:consumer, output_file, subscribe_to: [{producer, max_demand: @max_demand, min_demand: @min_demand}]}
  end

  def handle_events(events, _from, output_file) do
    events
    |> Stream.map(&process_item/1)
    |> CsvWriter.write(output_file)

    {:noreply, [], output_file}
  end
end
