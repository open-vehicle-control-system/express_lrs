defmodule ExpressLrs.Mavlink.FrameTest do
  use ExUnit.Case, async: true

  alias ExpressLrs.Mavlink.Frame

  # A plausible MAVLink v2 HEARTBEAT frame body (without the 0xFD STX).
  # Wire order for HEARTBEAT payload:
  #   uint32 custom_mode, uint8 type, uint8 autopilot, uint8 base_mode,
  #   uint8 system_status, uint8 mavlink_version
  @heartbeat_payload <<0, 0, 0, 0, 1, 3, 0, 4, 3>>
  @heartbeat_length byte_size(@heartbeat_payload)
  # message_id = 0 (HEARTBEAT), CRC_EXTRA = 50
  @heartbeat_crc_extra 50

  defp heartbeat_body do
    <<
      @heartbeat_length,
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
      # message_id (3 bytes little-endian)
      0,
      0,
      0,
      @heartbeat_payload::binary
    >>
  end

  describe "build_from_raw_data/1" do
    test "parses a well-formed frame body" do
      body = heartbeat_body() <> <<0xAB, 0xCD>>

      frame = Frame.build_from_raw_data(body)

      assert frame.length == @heartbeat_length
      assert frame.incompatibility_flags == 0
      assert frame.compatibility_flags == 0
      assert frame.sequence == 0
      assert frame.system_id == 1
      assert frame.component_id == 1
      assert frame.message_id == 0
      assert frame.payload == @heartbeat_payload
      assert frame.checksum == 0xCDAB
      assert frame.raw == body
    end

    test "returns nil on a truncated buffer" do
      assert Frame.build_from_raw_data(<<1, 2, 3>>) == nil
    end
  end

  describe "crc/2" do
    test "matches the checksum produced by a fresh round-trip" do
      body = heartbeat_body()
      placeholder = body <> <<0, 0>>
      computed = Frame.crc(%Frame{raw: placeholder}, @heartbeat_crc_extra)

      signed = body <> <<computed::little-unsigned-integer-size(16)>>
      frame = Frame.build_from_raw_data(signed)

      assert Frame.crc(frame, @heartbeat_crc_extra) == frame.checksum
    end

    test "is sensitive to payload changes" do
      body_a = heartbeat_body()

      body_b =
        heartbeat_body()
        |> :binary.bin_to_list()
        |> List.replace_at(-1, 99)
        |> :binary.list_to_bin()

      crc_a = Frame.crc(%Frame{raw: body_a <> <<0, 0>>}, @heartbeat_crc_extra)
      crc_b = Frame.crc(%Frame{raw: body_b <> <<0, 0>>}, @heartbeat_crc_extra)

      refute crc_a == crc_b
    end
  end
end
