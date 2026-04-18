defmodule ExpressLrs.Mavlink.RepositoryTest do
  use ExUnit.Case, async: false

  alias ExpressLrs.Mavlink.Repository
  alias ExpressLrs.Mavlink.Definition.MEnum

  setup do
    unless Process.whereis(Repository) do
      start_supervised!({Repository, []})
    end

    :ok
  end

  test "get_enum_by_name returns an enum added via :add_enum" do
    enum = %MEnum{name: "TEST_ENUM_RT", description: "round-trip", entries: []}
    :ok = GenServer.cast(Repository, {:add_enum, enum})

    assert Repository.get_enum_by_name("TEST_ENUM_RT") == enum
  end

  test "get_enum_by_name returns nil for unknown name" do
    assert Repository.get_enum_by_name("THIS_ENUM_DOES_NOT_EXIST_#{System.unique_integer()}") ==
             nil
  end
end
