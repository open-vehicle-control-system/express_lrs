defmodule ExpressLrs.Mavlink.Definition.Parser.State do
  defstruct [:stack, :repository_pid]
end

defmodule ExpressLrs.Mavlink.Definition.Parser do
  require Logger
  @behaviour Saxy.Handler
  alias ExpressLrs.Mavlink.Definition.Parser.State
  alias ExpressLrs.Mavlink.Definition.MMessage
  alias ExpressLrs.Mavlink.Definition.MEnum
  alias ExpressLrs.Mavlink.Definition.MField
  alias ExpressLrs.Mavlink.Definition.MEntry
  alias ExpressLrs.Mavlink.Definition.MGeneric
  alias ExpressLrs.Mavlink.Definition.MDescription

  def parse(repository_pid, definitions_file) do
    document = File.read!(definitions_file)
    Saxy.parse_string(document, __MODULE__, %State{stack: [], repository_pid: repository_pid})
  end

  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  def handle_event(:end_document, _data, state) do
    {:ok, state}
  end

  def handle_event(:start_element, {"extensions", _attributes}, %{stack: [head | tail]} = state)
      when head.__struct__ == MMessage do
    head = %{
      head
      | parser_options: head.parser_options |> Map.put(:next_fields_are_extensions, true)
    }

    {:ok, %{state | stack: [head | tail]}}
  end

  def handle_event(:start_element, {name, attributes}, state) do
    struct_module =
      case name do
        "message" -> MMessage
        "enum" -> MEnum
        "entry" -> MEntry
        "field" -> MField
        "description" -> MDescription
        _ -> MGeneric
      end

    resource = struct_module.build_from_tuple_list(name, attributes)
    {:ok, %{state | stack: [resource | state.stack]}}
  end

  def handle_event(:end_element, "extensions", %{stack: [head | tail]} = state)
      when head.__struct__ == MMessage do
    {:ok, %{state | stack: [head | tail]}}
  end

  def handle_event(:end_element, _name, %{stack: [head | tail]} = state) when tail != [] do
    [parent | tail] = tail

    {head, parent} =
      case {head.__struct__, parent} do
        {MGeneric, _} ->
          {head, parent}

        {_, %MGeneric{}} ->
          {head, parent}

        {_, nil} ->
          {head, parent}

        {_, parent} ->
          parent = parent |> parent.__struct__.add(head)
          {head, parent}
      end

    head |> add_to_repository(state)

    {:ok, %{state | stack: [parent | tail]}}
  end

  def handle_event(:end_element, _name, %{stack: [head]} = state) do
    head |> add_to_repository(state)
    {:ok, %{state | stack: []}}
  end

  def handle_event(:characters, characters, %{stack: [head | tail]} = state) do
    head = head.__struct__.add_characters(head, characters)
    {:ok, %{state | stack: [head | tail]}}
  end

  def handle_event(:cdata, cdata, state) do
    Logger.debug("Receive CData #{cdata}")
    {:ok, state}
  end

  def add_to_repository(%MMessage{} = message, state) do
    :ok = GenServer.cast(state.repository_pid, {:add_message, message})
    {:ok, state}
  end

  def add_to_repository(%MEnum{} = enum, state) do
    :ok = GenServer.cast(state.repository_pid, {:add_enum, enum})
    {:ok, state}
  end

  def add_to_repository(_resource, state) do
    {:ok, state}
  end
end
