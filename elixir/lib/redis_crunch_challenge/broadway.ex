defmodule RedisCrunchChallenge.Broadway do
  use Broadway

  import RedisCrunchChallenge.CoreProcessor

  alias Broadway.Message
  alias RedisCrunchChallenge.GenStage.Producer
  alias RedisCrunchChallenge.CsvWriter

  @producers_count 5
  @processors_count 40
  @max_demand 1000
  @min_demand 500
  @batchers_count 20
  @batch_size 2000

  def start_link(_opts) do
    IO.puts "Processing Broadway"

    define_supported_atoms()
    output_file = CsvWriter.output_file()

    Broadway.start_link(
      RedisCrunchChallenge.Broadway,
      name: RedisBroadway,
      producer: [
        module: {Producer, [list_name: "events_queue"]},
        transformer: {__MODULE__, :transform, []},
        concurrency: @producers_count
      ],
      processors: [
        default: [concurrency: @processors_count, max_demand: @max_demand, min_demand: @min_demand]
      ],
      batchers: [
        default: [concurrency: @batchers_count, batch_size: @batch_size],
      ],
      context: [output_file: output_file]
    )
  end

  def transform(event, _opts) do
    %Message{
      data: event,
      acknowledger: {__MODULE__, :ack_id, :ack_data}
    }
  end

  def ack(:ack_id, _successful, _failed) do
    :ok
  end

  @impl true
  def handle_message(_, message, _) do
    message
    |> Message.update_data(&process_item/1)
  end

  @impl true
  def handle_batch(_, messages, _batch_info, [output_file: output_file]) do
    # IO.puts "batch to file #{output_file}"
    messages
    |> Stream.map(fn %Message{data: data} -> data end)
    |> CsvWriter.write(output_file)

    messages
  end
end
