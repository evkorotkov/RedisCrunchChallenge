Mix.install([
  {:jason, "~> 1.4"},
  {:nimble_csv, "~> 1.2"},
  {:redix, "~> 1.2"}
])

defmodule Redis do
  def child_spec(opts \\ []) do
    pool_size = Keyword.get(opts, :pool_size, 5)
    host = Keyword.get(opts, :host)

    children =
      for index <- 0..(pool_size - 1) do
        Supervisor.child_spec({Redix, host: host, name: :"redix_#{index}"}, id: {Redix, index})
      end

    children = [
      %{
        id: __MODULE__,
        start: {Agent, :start_link, [fn -> {0, pool_size} end, [name: __MODULE__]]}
      }
      | children
    ]

    %{
      id: RedisSupervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }
  end

  def command(command) do
    Redix.command(:"redix_#{get_index()}", command)
  end

  defp get_index() do
    Agent.get_and_update(__MODULE__, fn
      {index, size} when index == size - 1 ->
        {index, {0, size}}

      {index, size} ->
        {index, {index + 1, size}}
    end)
  end
end

defmodule Worker do
  require Jason.Helpers

  @discounts %{
    0 => 0,
    1 => 5,
    2 => 10,
    3 => 15,
    4 => 20,
    5 => 25,
    6 => 30
  }

  @encode_order [:index, :wday, :payload, :price, :user_id, :total]

  def run(file) do
    case Redis.command(["BRPOP", "events_queue", "5"]) do
      {:ok, [_, event]} ->
        event
        |> Jason.decode!(keys: :atoms!)
        |> process()
        |> dump_to_csv(file)

        run(file)

      _ ->
        nil
    end
  end

  defp process(%{index: index, price: price, wday: wday} = data) do
    data =
      data
      |> Map.put_new_lazy(:total, fn ->
        Float.round(price * (1 - Map.get(@discounts, wday, 0) / 100.0) * 100) / 100
      end)
      |> Jason.Helpers.json_map_take(@encode_order)
      |> Jason.encode!()

    signature = :crypto.hash(:md5, data) |> Base.encode16(case: :lower)
    [index, signature]
  end

  defp dump_to_csv(data, file) do
    unix_time = DateTime.utc_now() |> DateTime.to_unix()

    IO.binwrite(file, NimbleCSV.RFC4180.dump_to_iodata([[unix_time | data]]))
  end
end

processes_count =
  with [count] <- System.argv(),
       {count, _} <- Integer.parse(count) do
    count
  else
    _ -> System.schedulers() * 50
  end

redis_pool_size = (processes_count / 10) |> round() |> max(1)

Supervisor.start_link(
  [
    {Redis, [pool_size: redis_pool_size, host: System.get_env("REDIS_HOST", "localhost")]}
  ],
  strategy: :one_for_one
)

unix_time = DateTime.utc_now() |> DateTime.to_unix()

file = File.open!("/scripts/output/elixir.csv.#{unix_time}", [:append, :binary])

1..processes_count
|> Enum.map(fn _ -> Task.async(Worker, :run, [file]) end)
|> Task.await_many(:infinity)

File.close(file)
