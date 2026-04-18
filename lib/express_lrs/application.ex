defmodule ExpressLrs.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ExpressLrs.Mavlink.Repository, []},
      {ExpressLrs.Mavlink.Parser, []},
      {ExpressLrs.Mavlink.Interpreter, []}
    ]

    children =
      if Application.get_env(:express_lrs, :enabled),
        do:
          children ++
            [{ExpressLrs.Mavlink.Connector, Application.get_env(:express_lrs, :interface)}],
        else: children

    opts = [strategy: :one_for_one, name: ExpressLrs.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
