Mix.install([
  {:bandit, ">= 0.0.0"},
])

defmodule Main do
  def run do
    {:ok, _pid} = Supervisor.start_link([
      {Bandit, plug: Router, scheme: :http, port: 4000},
    ], strategy: :one_for_one)
  end
end

Main.run()

# unless running from IEx, sleep idenfinitely so we can serve requests
unless IEx.started?() do
  Process.sleep(:infinity)
end
