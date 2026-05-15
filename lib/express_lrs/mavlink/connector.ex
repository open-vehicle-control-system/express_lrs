defmodule ExpressLrs.Mavlink.Connector.State do
  defstruct [:uart_pid, :uart_port, :uart_baud_rate]
end

defmodule ExpressLrs.Mavlink.Connector do
  @moduledoc """
  Owns the MAVLink UART. Tolerates a missing serial port at startup
  (host dev box, target with the radio not yet wired) by retrying
  with bounded backoff instead of crashing the supervisor — `:enoent`
  from `Circuits.UART.open/3` would otherwise take down the whole
  `express_lrs` application and, with it, the radio_control bridge.
  """
  alias Circuits.UART
  alias ExpressLrs.Mavlink.Connector.State
  alias ExpressLrs.Mavlink.Parser
  require Logger
  use GenServer

  @reconnect_initial_ms 1_000
  @reconnect_max_ms 30_000

  def init(%{uart_port: uart_port, uart_baud_rate: uart_baud_rate}) do
    state = %State{uart_port: uart_port, uart_baud_rate: uart_baud_rate}
    send(self(), {:connect, @reconnect_initial_ms})
    {:ok, state}
  end

  @spec start_link(nil) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    Logger.debug("Starting #{__MODULE__}...")
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def handle_info(
        {:connect, backoff_ms},
        %State{uart_port: port, uart_baud_rate: baud} = state
      ) do
    {:ok, uart_pid} = UART.start_link()

    case UART.open(uart_pid, port, speed: baud, active: true) do
      :ok ->
        Logger.info("#{__MODULE__} opened #{port} @ #{baud}")
        {:noreply, %{state | uart_pid: uart_pid}}

      {:error, reason} ->
        :ok = UART.stop(uart_pid)
        next = min(backoff_ms * 2, @reconnect_max_ms)

        Logger.warning(
          "#{__MODULE__} open #{port} failed: #{inspect(reason)}; retrying in #{backoff_ms}ms"
        )

        Process.send_after(self(), {:connect, next}, backoff_ms)
        {:noreply, state}
    end
  end

  def handle_info({:circuits_uart, _tty, data}, state) do
    Parser.new_bytes(data)
    {:noreply, state}
  end

  def handle_cast({:change_baud_rate, baud_rate}, %State{uart_pid: nil} = state) do
    Logger.warning("#{__MODULE__} change_baud_rate(#{baud_rate}) ignored — UART not open yet")

    {:noreply, %{state | uart_baud_rate: baud_rate}}
  end

  def handle_cast({:change_baud_rate, baud_rate}, state) do
    Logger.debug("change baud rate: #{inspect(baud_rate)}")
    UART.configure(state.uart_pid, speed: baud_rate)
    Parser.new_baud_rate(baud_rate)
    {:noreply, %{state | uart_baud_rate: baud_rate}}
  end

  def change_baud_rate(baud_rate) do
    GenServer.cast(__MODULE__, {:change_baud_rate, baud_rate})
  end
end
