defmodule ExpressLrs.Mavlink.ParserTest do
  use ExUnit.Case, async: false

  alias ExpressLrs.Mavlink.{Parser, Frame, Repository}

  # SYSTEM_TIME (id=2) is defined in priv/common.xml, which Repository loads at
  # boot. Any message from common.xml would do — SYSTEM_TIME is convenient
  # because it has a fixed, small base-field layout (uint64 + uint32 = 12 bytes).
  @message_id 2

  setup do
    # mix test starts :express_lrs, so Parser/Repository/Interpreter are already
    # registered. Just verify the Repository knows about our test message.
    assert Repository.get_crc_extra_for_message_id(@message_id) != nil,
           "Repository did not load SYSTEM_TIME (id=#{@message_id}) from common.xml"

    :ok
  end

  defp build_valid_frame(message_id, payload) do
    crc_extra = Repository.get_crc_extra_for_message_id(message_id)
    len = byte_size(payload)

    body = <<
      len,
      # incompat_flags
      0,
      # compat_flags
      0,
      # sequence
      0,
      # system_id
      1,
      # component_id
      1,
      message_id::little-unsigned-integer-size(24),
      payload::binary
    >>

    crc = Frame.crc(%Frame{raw: body <> <<0, 0>>}, crc_extra)
    <<0xFD, body::binary, crc::little-unsigned-integer-size(16)>>
  end

  defp parser_state, do: :sys.get_state(Parser)

  test "a well-formed frame increments valid_frames_count" do
    payload = <<0::size(96)>>
    bytes = build_valid_frame(@message_id, payload)

    before_state = parser_state()
    Parser.new_bytes(bytes)
    after_state = parser_state()

    assert after_state.valid_frames_count == before_state.valid_frames_count + 1
    assert after_state.invalid_crcs_count == before_state.invalid_crcs_count
  end

  test "a frame with a wrong checksum increments invalid_crcs_count" do
    payload = <<1, 2, 3, 4>>
    bytes = build_valid_frame(@message_id, payload)
    # Flip the low byte of the checksum so the computed CRC no longer matches.
    <<head::binary-size(byte_size(bytes) - 2), low::8, high::8>> = bytes
    corrupted = <<head::binary, bxor(low, 0xFF)::8, high::8>>

    before_state = parser_state()
    Parser.new_bytes(corrupted)
    after_state = parser_state()

    assert after_state.invalid_crcs_count == before_state.invalid_crcs_count + 1
    assert after_state.valid_frames_count == before_state.valid_frames_count
  end

  test "junk bytes before the magic are skipped and a following valid frame still parses" do
    payload = <<0::size(96)>>
    bytes = build_valid_frame(@message_id, payload)

    before_state = parser_state()
    Parser.new_bytes(<<0xAA, 0xBB, 0xCC>> <> bytes)
    after_state = parser_state()

    assert after_state.valid_frames_count == before_state.valid_frames_count + 1
  end

  # Using `import Bitwise` at the top would bleed into the test module; a
  # local alias keeps the import scope tight.
  defp bxor(a, b), do: Bitwise.bxor(a, b)
end
