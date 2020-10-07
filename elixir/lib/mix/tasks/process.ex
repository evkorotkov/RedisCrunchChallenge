defmodule Mix.Tasks.Process do
  use Mix.Task
  alias Mix.Tasks.Run

  def run(args) do
    {[mode: mode], _} =
      OptionParser.parse_head!(
        args,
        strict: [
          mode: :string,
        ]
      )

    Application.put_env(:redis_crunch_challenge, :mode, String.to_atom(mode), persistent: true)

    Run.run run_args()
  end

  defp run_args do
    if iex_running?(), do: [], else: ["--no-halt"]
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end
end
