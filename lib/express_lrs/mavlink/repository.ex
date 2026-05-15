defmodule ExpressLrs.Mavlink.Repository.State do
  defstruct messages_by_id: %{}, messages_by_name: %{}, enums_by_name: %{}
end

defmodule ExpressLrs.Mavlink.Repository do
  require Logger
  use GenServer
  alias ExpressLrs.Mavlink.Repository.State

  def init(_) do
    path = Path.join(:code.priv_dir(:express_lrs), "common.xml")
    {:ok, _} = ExpressLrs.Mavlink.Definition.Parser.parse(__MODULE__, path)
    {:ok, %State{}}
  end

  @spec start_link(nil) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) do
    Logger.debug("Starting #{__MODULE__}...")
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def handle_cast({:add_message, message}, state) do
    {:noreply,
     %{
       state
       | messages_by_id: state.messages_by_id |> Map.put(message.id, message),
         messages_by_name: state.messages_by_name |> Map.put(message.name, message)
     }}
  end

  def handle_cast({:add_enum, enum}, state) do
    {:noreply, %{state | enums_by_name: state.enums_by_name |> Map.put(enum.name, enum)}}
  end

  def handle_call({:get_message_by_id, id}, _from, state) do
    {:reply, state.messages_by_id[id], state}
  end

  def handle_call({:get_message_by_name, name}, _from, state) do
    {:reply, state.messages_by_name[name], state}
  end

  def handle_call({:get_enum_by_name, name}, _from, state) do
    {:reply, state.enums_by_name[name], state}
  end

  def get_message_by_id(id) do
    GenServer.call(__MODULE__, {:get_message_by_id, id})
  end

  def get_message_by_name(name) do
    GenServer.call(__MODULE__, {:get_message_by_name, name})
  end

  def get_enum_by_name(name) do
    GenServer.call(__MODULE__, {:get_enum_by_name, name})
  end

  def get_crc_extra_for_message_id(id) do
    message = GenServer.call(__MODULE__, {:get_message_by_id, id})

    case message do
      nil -> nil
      _ -> message.__struct__.crc_extra(message)
    end
  end
end
