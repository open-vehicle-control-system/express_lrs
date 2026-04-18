defmodule ExpressLrs.Mavlink.InterpreterTest do
  use ExUnit.Case, async: true

  alias ExpressLrs.Mavlink.Interpreter
  alias ExpressLrs.Mavlink.Definition.MField

  describe "field_value/3 uint8_t" do
    test "decodes a byte within payload" do
      field = %MField{type: "uint8_t", name: "byte"}
      payload = <<0x10, 0x20, 0x30>>

      assert Interpreter.field_value(field, 1, payload) == {0x20, 1}
    end

    test "decodes a high byte (>= 0x80) without grapheme truncation" do
      field = %MField{type: "uint8_t", name: "byte"}
      payload = <<0xFF>>

      assert Interpreter.field_value(field, 0, payload) == {0xFF, 1}
    end
  end

  describe "field_value/3 uint16_t" do
    test "decodes little-endian u16" do
      field = %MField{type: "uint16_t", name: "word"}
      # 0xBEEF little-endian: <<0xEF, 0xBE>>
      payload = <<0xEF, 0xBE, 0x00, 0x00>>

      assert Interpreter.field_value(field, 0, payload) == {0xBEEF, 2}
    end

    test "zero-pads a truncated payload on the right (MAVLink v2 truncation)" do
      field = %MField{type: "uint16_t", name: "word"}
      # Only one byte left at index 0; decoder must pad the high byte to 0x00.
      payload = <<0x42>>

      assert Interpreter.field_value(field, 0, payload) == {0x42, 2}
    end

    test "fully-truncated payload yields zero" do
      field = %MField{type: "uint16_t", name: "word"}
      payload = <<>>

      assert Interpreter.field_value(field, 0, payload) == {0, 2}
    end
  end

  describe "field_value/3 signed integers" do
    test "int8_t decodes negative values" do
      field = %MField{type: "int8_t", name: "s"}
      # -1 as signed int8 = 0xFF
      assert Interpreter.field_value(field, 0, <<0xFF>>) == {-1, 1}
    end

    test "int16_t decodes little-endian negative values" do
      field = %MField{type: "int16_t", name: "s"}
      # -2 as signed little-endian int16 = <<0xFE, 0xFF>>
      assert Interpreter.field_value(field, 0, <<0xFE, 0xFF>>) == {-2, 2}
    end

    test "int32_t decodes little-endian negative values" do
      field = %MField{type: "int32_t", name: "s"}
      # -3 little-endian int32 = <<0xFD, 0xFF, 0xFF, 0xFF>>
      assert Interpreter.field_value(field, 0, <<0xFD, 0xFF, 0xFF, 0xFF>>) == {-3, 4}
    end
  end

  describe "field_value/3 unsigned integers" do
    test "uint32_t decodes little-endian u32" do
      field = %MField{type: "uint32_t", name: "u"}
      assert Interpreter.field_value(field, 0, <<0x78, 0x56, 0x34, 0x12>>) == {0x12345678, 4}
    end

    test "uint64_t decodes little-endian u64" do
      field = %MField{type: "uint64_t", name: "u"}
      # 0x0102030405060708 little-endian
      bytes = <<0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01>>
      assert Interpreter.field_value(field, 0, bytes) == {0x0102030405060708, 8}
    end

    test "int64_t decodes little-endian signed i64" do
      field = %MField{type: "int64_t", name: "s"}
      assert Interpreter.field_value(field, 0, <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>) ==
               {-1, 8}
    end
  end

  describe "field_value/3 floats" do
    test "float decodes little-endian 32-bit IEEE-754" do
      field = %MField{type: "float", name: "f"}
      # 1.0f little-endian = <<0x00, 0x00, 0x80, 0x3F>>
      assert Interpreter.field_value(field, 0, <<0x00, 0x00, 0x80, 0x3F>>) == {1.0, 4}
    end

    test "double decodes little-endian 64-bit IEEE-754" do
      field = %MField{type: "double", name: "d"}
      # 2.0 little-endian = <<0, 0, 0, 0, 0, 0, 0x00, 0x40>>
      bytes = <<0, 0, 0, 0, 0, 0, 0x00, 0x40>>
      assert Interpreter.field_value(field, 0, bytes) == {2.0, 8}
    end
  end

  describe "field_value/3 char" do
    test "char returns a single-byte binary" do
      field = %MField{type: "char", name: "c"}
      assert Interpreter.field_value(field, 0, "A") == {"A", 1}
    end
  end

  describe "field_value/3 unknown type" do
    test "logs a warning and returns {nil, 0} instead of crashing" do
      field = %MField{type: "nonexistent_t", name: "x"}

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert Interpreter.field_value(field, 0, <<1, 2, 3>>) == {nil, 0}
        end)

      assert log =~ "unsupported MAVLink field type"
      assert log =~ "nonexistent_t"
    end
  end

  describe "slice_with_padding/3" do
    test "returns exactly `size` bytes when data has enough" do
      assert Interpreter.slice_with_padding(<<1, 2, 3, 4>>, 1, 2) == <<2, 3>>
    end

    test "pads zero bytes on the right when data is shorter" do
      assert Interpreter.slice_with_padding(<<1>>, 0, 4) == <<1, 0, 0, 0>>
    end

    test "pads fully when index is past end of data" do
      assert Interpreter.slice_with_padding(<<1, 2>>, 5, 3) == <<0, 0, 0>>
    end
  end
end
