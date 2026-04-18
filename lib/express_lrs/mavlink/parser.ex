defmodule ExpressLrs.Mavlink.Parser.State do
  defstruct [
    :buffer,
    :valid_frames_count,
    :invalid_frames_count,
    :invalid_crcs_count,
    :statistics_timer
  ]
end

defmodule ExpressLrs.Mavlink.Parser do
  alias ExpressLrs.Mavlink.Parser.State
  alias ExpressLrs.Mavlink.{Repository, Frame, Interpreter}

  require Logger
  use GenServer

  @empty_buffer <<>>
  @mavlink_v2_magic 0xFD
  @mavlink_v2_minimum_packet_length 12
  @statistics_loop_period 5000

  @impl true
  def init(_) do
    {:ok, timer} = :timer.send_interval(@statistics_loop_period, :loop)

    {:ok,
     %State{
       buffer: @empty_buffer,
       valid_frames_count: 0,
       invalid_frames_count: 0,
       invalid_crcs_count: 0,
       statistics_timer: timer
     }}
  end

  @spec start_link(nil) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    Logger.debug("Starting #{__MODULE__}...")
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def handle_info(:loop, state) do
    {:message_queue_len, message_queue_length} = :erlang.process_info(self(), :message_queue_len)

    Logger.debug(
      "#{__MODULE__} invalid frames: #{state.invalid_frames_count} | " <>
        "invalid crcs count: #{state.invalid_crcs_count} | " <>
        "valid frames: #{state.valid_frames_count} | " <>
        "valid/invalid ratio: #{(state.valid_frames_count / max(state.valid_frames_count + state.invalid_frames_count + state.invalid_crcs_count, 1) * 100) |> Float.ceil(2)} | " <>
        "message queue length: #{message_queue_length}"
    )

    Logger.flush()
    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_baud_rate, _baud_rate}, state) do
    state = %{state | valid_frames_count: 0, invalid_frames_count: 0, invalid_crcs_count: 0}
    {:noreply, state}
  end

  def handle_cast({:new_bytes, data}, state) do
    state = %{state | buffer: state.buffer <> data}
    state = search_complete_frame_in_buffer(state)
    {:noreply, state}
  end

  def search_complete_frame_in_buffer(state)
      when byte_size(state.buffer) >= @mavlink_v2_minimum_packet_length do
    <<magic_candidate::unsigned-integer-size(8), buffer_candidate::bitstring>> = state.buffer

    state =
      case magic_candidate do
        @mavlink_v2_magic ->
          {frame_candidate, buffer} = buffer_candidate |> extract_frame_candidate()

          state =
            frame_candidate
            |> Frame.build_from_raw_data()
            |> compute_crc()
            |> publish_frame(state)

          state = %{state | buffer: buffer}
          search_complete_frame_in_buffer(state)

        _ ->
          state = %{state | buffer: buffer_candidate}
          search_complete_frame_in_buffer(state)
      end

    state
  end

  def search_complete_frame_in_buffer(state) do
    state
  end

  def extract_frame_candidate(
        <<len::unsigned-integer-size(8), frame_candidate::binary-size(len + 10), rest::bitstring>>
      ) do
    {<<len, frame_candidate::bitstring>>, rest}
  end

  def extract_frame_candidate(rest) do
    {nil, rest}
  end

  def compute_crc(nil) do
    nil
  end

  def compute_crc(frame) do
    crc_extra = Repository.get_crc_extra_for_message_id(frame.message_id)

    crc =
      case crc_extra do
        nil -> nil
        _ -> frame |> Frame.crc(crc_extra)
      end

    %{frame | computed_checksum: crc}
  end

  def publish_frame(nil, state) do
    %{state | invalid_frames_count: state.invalid_frames_count + 1}
  end

  def publish_frame(frame, state) do
    if frame.checksum == frame.computed_checksum do
      :ok = Interpreter.new_frame(frame)
      %{state | valid_frames_count: state.valid_frames_count + 1}
    else
      %{state | invalid_crcs_count: state.invalid_crcs_count + 1}
    end
  end

  def new_bytes(bytes) do
    GenServer.cast(__MODULE__, {:new_bytes, bytes})
  end

  def new_baud_rate(baud_rate) do
    GenServer.cast(__MODULE__, {:new_baud_rate, baud_rate})
  end
end
