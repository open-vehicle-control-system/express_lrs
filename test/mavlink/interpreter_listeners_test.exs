defmodule ExpressLrs.Mavlink.InterpreterListenersTest do
  use ExUnit.Case, async: false

  alias ExpressLrs.Mavlink.{Interpreter, Repository, Frame}

  @message_id 2

  setup do
    # Clear any leftover listeners from previous tests.
    :sys.replace_state(Interpreter, fn state -> %{state | listeners: %{}} end)
    :ok
  end

  defp listener_map, do: :sys.get_state(Interpreter).listeners

  defp send_test_frame do
    crc_extra = Repository.get_crc_extra_for_message_id(@message_id)
    payload = <<0::size(96)>>
    len = byte_size(payload)

    body = <<
      len,
      0,
      0,
      0,
      1,
      1,
      @message_id::little-unsigned-integer-size(24),
      payload::binary
    >>

    crc = Frame.crc(%Frame{raw: body <> <<0, 0>>}, crc_extra)

    frame = %Frame{
      length: len,
      incompatibility_flags: 0,
      compatibility_flags: 0,
      sequence: 0,
      system_id: 1,
      component_id: 1,
      message_id: @message_id,
      payload: payload,
      checksum: crc,
      raw: body <> <<crc::little-unsigned-integer-size(16)>>
    }

    Interpreter.new_frame(frame)
  end

  test "registering self delivers a decoded message" do
    Interpreter.register_listener(self())
    # sync: make sure register is applied before the frame arrives
    _ = listener_map()

    send_test_frame()

    assert_receive {:"$gen_cast", {:mavlink_message, _message}}, 200
  end

  test "registering the same listener twice only delivers once" do
    Interpreter.register_listener(self())
    Interpreter.register_listener(self())
    assert map_size(listener_map()) == 1

    send_test_frame()

    assert_receive {:"$gen_cast", {:mavlink_message, _}}, 200
    refute_receive {:"$gen_cast", {:mavlink_message, _}}, 50
  end

  test "a dead listener is removed from the registry" do
    parent = self()

    pid =
      spawn(fn ->
        send(parent, :registered)
        Process.sleep(:infinity)
      end)

    Interpreter.register_listener(pid)
    assert_receive :registered
    # Flush the register_listener cast.
    _ = listener_map()
    assert Map.has_key?(listener_map(), pid)

    # Monitor the target ourselves so we can wait for its death deterministically.
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 200

    # The Interpreter's own :DOWN delivery races ours; poll briefly.
    removed? =
      Enum.any?(1..20, fn _ ->
        Process.sleep(10)
        not Map.has_key?(listener_map(), pid)
      end)

    assert removed?, "dead listener was not removed from interpreter state"
  end
end
