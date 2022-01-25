defmodule SourceTest do
  use ExUnit.Case, async: false
  import Mock
  alias Basic.Elements.Source
  doctest Basic.Elements.Source


  @options %Source{location: "path/to/file"}

  describe "Source" do
    test "is initialized properly" do
      {:ok, state} = Source.handle_init(@options)
      assert state.location == @options.location
      assert state.content == nil
    end

    test "reads the input file correctly" do
      with_mock File, [read!: fn _ -> "First Line\nSecond Line" end] do
        {{:ok, _}, state} = Source.handle_stopped_to_prepared(nil, %{location: "heh.txt", content: nil})
        assert state.content == ["First Line", "Second Line"]
      end
    end
  end

end
