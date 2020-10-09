defmodule RedisCrunchChallenge.CsvWriter do
  def write(rows, file_name) do
    rows
    |> NimbleCSV.RFC4180.dump_to_stream
    |> Stream.into(File.stream!(file_name, [:append]))
    |> Stream.run
  end

  def output_file do
    file_name = Application.fetch_env!(:redis_crunch_challenge, :output_file_name)
    unix_time = DateTime.utc_now() |> DateTime.to_unix()

    "#{file_name}.#{unix_time}.csv"
  end
end
