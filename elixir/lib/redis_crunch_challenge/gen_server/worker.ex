defmodule RedisCrunchChallenge.GenServer.Worker do
  use GenServer

  import RedisCrunchChallenge.CoreProcessor
  alias RedisCrunchChallenge.CsvWriter
  alias RedisCrunchChallenge.DataSource

  def start_link([name: name, list_name: list_name, file_name: file_name]) do
    GenServer.start_link(__MODULE__, {list_name, file_name, name}, name: name)
  end

  @impl true
  def init({_, _, name} = state) do
    define_supported_atoms()
    schedule_cast(name)

    {:ok, state}
  end

  defp schedule_cast(name) do
    Process.send_after(name, :schedule_cast, 1_000)
  end

  def handle_info(:schedule_cast, {_, _, name} = state) do
    cast_process(name)

    {:noreply, state}
  end

  def cast_process(name), do: GenServer.cast(name, :process)

  @impl true
  def handle_cast(:process, {_, _, name} = state) do
    case process(state) do
      {:ok, _} ->
        cast_process(name)
        {:noreply, state, 0}
      {:error, reason} ->
        IO.puts "Terminating because of #{reason}"
        {:stop, reason, state}
    end
  end

  defp process({list_name, file_name, _}) do
    case DataSource.brpop(:redix, list_name) do
      {:ok, [_, item]} ->
        item = process_item(item)
        CsvWriter.write([item], file_name)
        {:ok, item}
      {:error, reason} -> {:error, reason}
    end
  end
end
