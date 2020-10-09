defmodule RedisCrunchChallenge.DataSource do
  def stream(list_name) do
    Stream.resource(
      fn ->
        {:ok, pid} = Redix.start_link(redis_config())
        pid
      end,
      fn pid ->
        case brpop(pid, list_name) do
          {:ok, [_, item]} -> {[item], pid}
          {:error, _} -> {:halt, pid}
        end
      end,
      fn pid ->
        # IO.puts "Redis is empty"
        Redix.stop(pid)
      end
    )
  end

  def redis_config do
    Application.fetch_env!(:redis_crunch_challenge, :redis)
  end

  def brpop(pid, list_name) do
    Redix.command(pid, ["BRPOP", list_name, 0])
  end
end
