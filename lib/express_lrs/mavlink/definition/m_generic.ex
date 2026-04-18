defmodule ExpressLrs.Mavlink.Definition.MGeneric do
  defstruct [:name, :attributes]

  def build_from_tuple_list(name, attributes) do
    attributes = attributes |> Enum.into(%{})

    %__MODULE__{
      name: name,
      attributes: attributes
    }
  end

  def add_characters(resource, _) do
    resource
  end
end
