defmodule MixerTest do
  use ExUnit.Case
  alias Basic.Elements.Mixer
  alias Membrane.Buffer

  import Membrane.Testing.Assertions
  alias Membrane.Testing.{Source, Sink, Pipeline}
  import Membrane.ChildrenSpec
  alias Basic.Formats.Frame

  doctest Basic.Elements.Mixer

  @first_input_frames [
    %Buffer{payload: "TEST FRAME", pts: 2},
    %Buffer{payload: "TEST FRAME", pts: 5}
  ]

  @second_input_frames [
    %Buffer{payload: "TEST FRAME", pts: 1},
    %Buffer{payload: "TEST FRAME", pts: 3},
    %Buffer{payload: "TEST FRAME", pts: 4}
  ]

  test "Mixer should mix frames coming from two sources, based on the timestamps" do
    generator = fn state, size ->
      if state == [] do
        {[end_of_stream: :output], state}
      else
        [buffer | new_state] = state

        if size > 1 do
          {[buffer: {:output, buffer}, redemand: :output], new_state}
        else
          {[buffer: {:output, buffer}], new_state}
        end
      end
    end

    structure = [
      child(:source1, %Source{
        output: {@first_input_frames, generator},
        stream_format: %Frame{encoding: :utf8}
      })
      |> via_in(:first_input)
      |> child(:mixer, Mixer)
      |> child(:sink, Sink),
      child(:source2, %Source{
        output: {@second_input_frames, generator},
        stream_format: %Frame{encoding: :utf8}
      })
      |> via_in(:second_input)
      |> get_child(:mixer)
    ]

    pipeline = Pipeline.start_link_supervised!(structure: structure)
    assert_start_of_stream(pipeline, :sink)
    # The idea is to chceck if the frames came in the proper order
    assert_sink_buffer(pipeline, :sink, %Buffer{pts: 1})
    assert_sink_buffer(pipeline, :sink, %Buffer{pts: 2})
    assert_sink_buffer(pipeline, :sink, %Buffer{pts: 3})
    assert_sink_buffer(pipeline, :sink, %Buffer{pts: 4})
    assert_sink_buffer(pipeline, :sink, %Buffer{pts: 5})
    # And this sequence of assertions apparently deos not chceck the order
    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 0)
    Pipeline.terminate(pipeline, blocking?: true)
  end
end
