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
        <<value::unsigned-integer-size(8)>> = slice_with_padding(data, index, 1)
        {value, 1}

      "int8_t" ->
        <<value::signed-integer-size(8)>> = slice_with_padding(data, index, 1)
        {value, 1}

      "uint16_t" ->
        <<value::little-unsigned-integer-size(16)>> = slice_with_padding(data, index, 2)
        {value, 2}

      "int16_t" ->
        <<value::little-signed-integer-size(16)>> = slice_with_padding(data, index, 2)
        {value, 2}

      "uint32_t" ->
        <<value::little-unsigned-integer-size(32)>> = slice_with_padding(data, index, 4)
        {value, 4}

      "int32_t" ->
        <<value::little-signed-integer-size(32)>> = slice_with_padding(data, index, 4)
        {value, 4}

      "uint64_t" ->
        <<value::little-unsigned-integer-size(64)>> = slice_with_padding(data, index, 8)
        {value, 8}

      "int64_t" ->
        <<value::little-signed-integer-size(64)>> = slice_with_padding(data, index, 8)
        {value, 8}

      "float" ->
        <<value::little-float-size(32)>> = slice_with_padding(data, index, 4)
        {value, 4}

      "double" ->
        <<value::little-float-size(64)>> = slice_with_padding(data, index, 8)
        {value, 8}

      "char" ->
        <<value::binary-size(1)>> = slice_with_padding(data, index, 1)
        {value, 1}

      other ->
        Logger.warning(
          "#{__MODULE__}: unsupported MAVLink field type #{inspect(other)} " <>
            "for field #{inspect(field.name)}; skipping"
        )

        {nil, 0}
    end
  end

  # Returns `size` bytes from `data` starting at `index`, zero-padding on the
  # right if `data` is shorter than expected. MAVLink v2 strips trailing zero
  # bytes from the payload, so decoders must re-pad before extracting fields.
  def slice_with_padding(data, index, size) do
    take = data |> byte_size() |> Kernel.-(index) |> max(0) |> min(size)
    chunk = if take > 0, do: binary_part(data, index, take), else: <<>>
    chunk <> :binary.copy(<<0>>, size - take)
  end

  def new_frame(frame) do
    GenServer.cast(__MODULE__, {:new_frame, frame})
  end

  def register_listener(listener) do
    GenServer.cast(__MODULE__, {:register_listener, listener})
  end
end
