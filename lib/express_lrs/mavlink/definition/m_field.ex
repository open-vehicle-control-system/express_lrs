defmodule ExpressLrs.Mavlink.Definition.MField do
  @enforce_keys [:type, :name]
  defstruct [
    :type,
    :name,
    :enum,
    :units,
    :multiplier,
    :display,
    :print_format,
    :default,
    :increment,
    :min_value,
    :max_value,
    :instance,
    :array_length,
    :value
  ]

  def build_from_tuple_list(_name, attributes) do
    attributes = attributes |> Enum.into(%{})

    %__MODULE__{
      type: attributes["type"],
      name: attributes["name"],
      enum: attributes["enum"]
    }
  end

  def add_characters(field, _) do
    field
  end
end
