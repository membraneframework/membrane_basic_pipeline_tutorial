defmodule SourceTest do
  use ExUnit.Case, async: false
  import Mock
  alias Basic.Elements.Source
  alias Membrane.Buffer

  doctest Basic.Elements.Source

  @exemplary_content ["First Line", "Second Line"]
  @exemplary_location "path/to/file"
  @options %Source{location: @exemplary_location}

  describe "Source" do
    test "is initialized properly" do
      {_, state} = Source.handle_init(nil, @options)
      assert state.location == @options.location
      assert state.content == nil
    end

    test "reads the input file correctly" do
      with_mock File, read!: fn _ -> "First Line\nSecond Line" end do
        {_, state} = Source.handle_playing(nil, %{location: @exemplary_location, content: nil})

        assert state.content == @exemplary_content
      end
    end

    test "supplies the buffers" do
      {actions, state} =
        Source.handle_demand(:output, 1, :buffers, nil, %{
          location: @exemplary_location,
          content: @exemplary_content
        })

      assert length(state.content) == length(@exemplary_content) - 1
      assert Keyword.has_key?(actions, :buffer)

      assert Keyword.get(actions, :buffer) ==
               {:output, %Buffer{payload: Enum.at(@exemplary_content, 0)}}
    end

    test "redemands if more then one buffer is demanded" do
      {actions, state} =
        Source.handle_demand(:output, 2, :buffers, nil, %{
          location: @exemplary_location,
          content: @exemplary_content
        })

      assert length(state.content) == length(@exemplary_content) - 1

      assert actions == [
               buffer: {:output, %Buffer{payload: Enum.at(@exemplary_content, 0)}},
               redemand: :output
             ]
    end

    test "sends end of stream once there are no buffers" do
      {actions, state} =
        Source.handle_demand(:output, 1, :buffers, nil, %{
          location: @exemplary_location,
          content: []
        })

      assert state == %{location: @exemplary_location, content: []}
      assert actions == [end_of_stream: :output]
    end
  end
end
