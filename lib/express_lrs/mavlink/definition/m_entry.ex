defmodule ExpressLrs.Mavlink.Definition.MEntry do
  @enforce_keys [:name, :value]
  defstruct [:name, :value, :description]

  def build_from_tuple_list(_name, attributes) do
    attributes = attributes |> Enum.into(%{})

    %__MODULE__{
      name: attributes["name"],
      value: attributes["value"]
    }
  end

  def add(entry, %ExpressLrs.Mavlink.Definition.MDescription{} = description) do
    %{entry | description: description.value}
  end

  def add_characters(entry, _) do
    entry
  end
end
