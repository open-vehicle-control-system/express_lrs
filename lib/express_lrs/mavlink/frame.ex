defmodule ExpressLrs.Mavlink.Frame do
  defstruct [
    :length,
    :incompatibility_flags,
    :compatibility_flags,
    :sequence,
    :system_id,
    :component_id,
    :message_id,
    :payload,
    :checksum,
    :computed_checksum,
    :raw,
    :message
  ]

  def build_from_raw_data(
        <<
          length::unsigned-integer-size(8),
          incompatibility_flags,
          compatibility_flags,
          sequence,
          system_id,
          component_id,
          message_id::little-unsigned-integer-size(3 * 8),
          payload::binary-size(length),
          checksum::little-unsigned-integer-size(2 * 8)
        >> = data
      ) do
    %__MODULE__{
      length: length,
      incompatibility_flags: incompatibility_flags,
      compatibility_flags: compatibility_flags,
      sequence: sequence,
      system_id: system_id,
      component_id: component_id,
      message_id: message_id,
      payload: payload,
      checksum: checksum,
      raw: data
    }
  end

  def build_from_raw_data(_) do
    nil
  end

  def crc_data(frame) do
    {crc_data, _checksum} = frame.raw |> String.split_at(-2)
    crc_data
  end

  def crc(frame, crc_extra) do
    CRC.crc_init(:crc_16_mcrf4xx)
    |> CRC.crc_update(frame |> __MODULE__.crc_data())
    |> CRC.crc_update(<<crc_extra>>)
    |> CRC.crc_final()
  end
end
