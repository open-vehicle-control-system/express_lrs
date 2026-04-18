defmodule ExpressLrs.Mavlink.Interpreter.State do
  defstruct listeners: []
end

defmodule ExpressLrs.Mavlink.Interpreter do
  alias ExpressLrs.Mavlink.Interpreter.State
  alias ExpressLrs.Mavlink.Repository

  require Logger
  use GenServer

  def init(_) do
    {:ok, %State{}}
  end

  @spec start_link(nil) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    Logger.debug("Starting #{__MODULE__}...")
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def handle_cast({:new_frame, frame}, state) do
    message = Repository.get_message_by_id(frame.message_id)

    {base_fields, _} =
      message.base_fields
      |> Enum.reduce({[], 0}, fn field, {fields, index} ->
        {value, bytes} = field |> field_value(index, frame.payload)
        field = %{field | value: value}
        {fields ++ [field], index + bytes}
      end)

    message = %{message | base_fields: base_fields}

    state.listeners
    |> Enum.each(fn listener ->
      GenServer.cast(listener, {:mavlink_message, message})
    end)

    {:noreply, state}
  end

  def handle_cast({:register_listener, listener}, state) do
    {:noreply, %{state | listeners: state.listeners ++ [listener]}}
  end

  def field_value(field, index, data) do
    case field.type do
      "uint8_t" ->
        data = data |> String.slice(index, 1) |> append_zeros(1)
        <<data::unsigned-integer-size(8)>> = data
        {data, 1}

      "uint16_t" ->
        data = data |> String.slice(index, 2) |> append_zeros(2)
        <<data::little-unsigned-integer-size(16)>> = data
        {data, 2}
    end
  end

  def append_zeros(nil, expected_bytes) do
    append_zeros(<<0x00>>, expected_bytes)
  end

  def append_zeros(data, expected_bytes) do
    if byte_size(data) >= expected_bytes do
      data
    else
      append_zeros(<<data::bitstring, 0x00>>, expected_bytes)
    end
  end

  def new_frame(frame) do
    GenServer.cast(__MODULE__, {:new_frame, frame})
  end

  def register_listener(listener) do
    GenServer.cast(__MODULE__, {:register_listener, listener})
  end
end
