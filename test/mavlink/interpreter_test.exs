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
