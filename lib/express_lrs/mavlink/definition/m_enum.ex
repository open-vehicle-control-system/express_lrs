defmodule ExpressLrs.Mavlink.Definition.MEnum do
  @enforce_keys [:name]
  defstruct [:name, :description, :entries]

  def build_from_tuple_list(_name, attributes) do
    attributes = attributes |> Enum.into(%{})

    %__MODULE__{
      name: attributes["name"]
    }
  end

  def add(enum, %__MODULE__{} = _enum) do
    enum
  end

  def add(enum, %ExpressLrs.Mavlink.Definition.MEntry{} = entry) do
    entries = enum.entries || []
    %{enum | entries: entries ++ [entry]}
  end

  def add(enum, %ExpressLrs.Mavlink.Definition.MDescription{} = description) do
    %{enum | description: description.value}
  end

  def add_characters(enum, _) do
    enum
  end
end
