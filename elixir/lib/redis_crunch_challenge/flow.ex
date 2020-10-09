defmodule RedisCrunchChallenge.Flow do
  use Flow

  alias RedisCrunchChallenge.CsvWriter
  alias RedisCrunchChallenge.DataSource
  import RedisCrunchChallenge.CoreProcessor

  def start_link(list_name: list_name) do
    IO.puts "Processing Flow"

    process(list_name)
    |> Flow.start_link
  end

  def process(list_name) do
    define_supported_atoms()
    output_file = output_file()

    DataSource.stream(list_name)
    |> Flow.from_enumerable(stages: 1)
    |> Flow.partition(max_demand: 1000, stages: 5)
    |> Flow.map(&process_item/1)
    |> CsvWriter.write(output_file)
  end

  defp output_file do
    RedisCrunchChallenge.CsvWriter.output_file()
  end
end
