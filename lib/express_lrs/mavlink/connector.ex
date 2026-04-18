defmodule ExpressLrs.Mavlink.Connector.State do
  defstruct [:uart_pid, :uart_port]
end

defmodule ExpressLrs.Mavlink.Connector do
  alias Circuits.UART
  alias ExpressLrs.Mavlink.Connector.State
  alias ExpressLrs.Mavlink.Parser
  require Logger
  use GenServer

  def init(%{uart_port: uart_port, uart_baud_rate: uart_baud_rate}) do
    {:ok, uart_pid} = UART.start_link()
    :ok = UART.open(uart_pid, uart_port, speed: uart_baud_rate, active: true)

    {:ok,
     %State{
       uart_pid: uart_pid,
       uart_port: uart_port
     }}
  end

  @spec start_link(nil) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    Logger.debug("Starting #{__MODULE__}...")
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def handle_info({:circuits_uart, _tty, data}, state) do
    Parser.new_bytes(data)
    {:noreply, state}
  end

  def handle_cast({:change_baud_rate, baud_rate}, state) do
    Logger.debug("change baud rate: #{inspect(baud_rate)}")
    UART.configure(state.uart_pid, speed: baud_rate)
    Parser.new_baud_rate(baud_rate)
    {:noreply, state}
  end

  def change_baud_rate(baud_rate) do
    GenServer.cast(__MODULE__, {:change_baud_rate, baud_rate})
  end
end
