defmodule RedisCrunchChallenge.GenStage.Producer do
  alias RedisCrunchChallenge.DataSource

  use GenStage

  def start_link(name: name, list_name: list_name) do
    GenStage.start_link(__MODULE__, [list_name: list_name], name: name)
  end

  def init(opts \\ []) do
    [list_name: list_name] =  Keyword.take(opts, [:list_name])

    source = DataSource.stream(list_name)

    {:producer, source}
  end

  def handle_demand(demand, source) do
    events =
      source
      |> Stream.take(demand)
      |> Enum.to_list()

    if Enum.empty?(events) do
      {:stop, :empty, source}
    else
      {:noreply, events, source}
    end
  end
end
