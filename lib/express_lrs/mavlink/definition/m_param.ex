defmodule ExpressLrs.Mavlink.Definition.MParam do
  @enforce_keys [:index, :label]
  defstruct [
    :index,
    :description,
    :label,
    :units,
    :enum,
    :decimal_places,
    :increment,
    :min_value,
    :max_value,
    :multiplier,
    :reversed,
    :default
  ]
end
