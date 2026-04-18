defmodule ExpressLrs.Mavlink.Definition.MMessage do
  import Bitwise

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :description, :base_fields, :extension_fields, parser_options: %{}]

  @data_type_size %{
    "int64_t" => 8,
    "uint64_t" => 8,
    "double" => 8,
    "int32_t" => 4,
    "uint32_t" => 4,
    "float" => 4,
    "int16_t" => 2,
    "uint16_t" => 2,
    "int8_t" => 1,
    "uint8_t" => 1,
    "char" => 1
  }

  def build_from_tuple_list(_name, attributes) do
    attributes = attributes |> Enum.into(%{})

    %__MODULE__{
      id: attributes["id"] |> String.to_integer(),
      name: attributes["name"]
    }
  end

  def add(message, %__MODULE__{} = _message) do
    message
  end

  def add(message, %ExpressLrs.Mavlink.Definition.MField{} = field) do
    case message.parser_options |> Map.get(:next_fields_are_extensions, false) do
      false ->
        fields = message.base_fields || []
        fields = fields ++ [field]
        fields = fields |> Enum.sort_by(fn field -> @data_type_size[field.type] end, :desc)
        %{message | base_fields: fields}

      true ->
        fields = message.extension_fields || []
        %{message | extension_fields: fields ++ [field]}
    end
  end

  def add(message, %ExpressLrs.Mavlink.Definition.MDescription{} = description) do
    %{message | description: description.value}
  end

  def add_characters(message, _) do
    message
  end

  def crc_extra(message) do
    crc =
      CRC.crc_init(:crc_16_x_25)
      |> CRC.crc_update(message.name <> " ")

    crc =
      message.base_fields
      |> Enum.reduce(crc, fn field, crc ->
        crc =
          crc
          |> CRC.crc_update(field.type <> " ")
          |> CRC.crc_update(field.name <> " ")

        case field.array_length do
          nil -> crc
          _ -> crc |> CRC.crc_update(<<field.array_length>>)
        end
      end)
      |> CRC.crc_final()

    bxor(crc &&& 0xFF, crc >>> 8)
  end
end
