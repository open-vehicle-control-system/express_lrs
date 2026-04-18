defmodule ExpressLrs.Mavlink.Definition.MDescription do
  @enforce_keys [:value]
  defstruct [:value]

  def build_from_tuple_list(_name, attributes) do
    attributes = attributes |> Enum.into(%{})

    %__MODULE__{
      value: attributes["value"]
    }
  end

  def add_characters(description, characters) do
    %{description | value: characters}
  end
end
