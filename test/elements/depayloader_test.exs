defmodule DepayloaderTest do
  use ExUnit.Case
  alias Basic.Elements.Depayloader
  alias Membrane.Buffer

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions
  alias Membrane.Testing.{Source, Sink, Pipeline}
  alias Basic.Formats.Packet

  doctest Basic.Elements.Depayloader

  test "Depayloader should assemble the packets and form a frame (with membrane's testing framework)" do
    inputs = [
      "[frameid:1s][timestamp:1]Hello! ",
      "[frameid:1][timestamp:1]How are",
      "[frameid:1e][timestamp:1] you?"
    ]

    spec =
      child(:source, %Source{output: inputs, stream_format: %Packet{type: :custom_packets}})
      |> child(:depayloader, %Depayloader{packets_per_frame: 5})
      |> child(:sink, Sink)

    pipeline = Pipeline.start_link_supervised!(spec: spec)
    assert_start_of_stream(pipeline, :sink)

    assert_sink_buffer(pipeline, :sink, %Buffer{payload: "Hello! How are you?"})

    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 0)
    Pipeline.terminate(pipeline)
  end

  test "Depayloader should assemble the packets and form a frame (with membrane's testing framework based on generator)" do
    initial_state = [
      "[frameid:1s][timestamp:1]Hello! ",
      "[frameid:1][timestamp:1]How are",
      "[frameid:1e][timestamp:1] you?"
    ]

    generator = fn state, size ->
      if state == [] do
        {[end_of_stream: :output], state}
      else
        [payload | new_state] = state

        if size > 1 do
          {[buffer: {:output, %Buffer{payload: payload}}, redemand: :output], new_state}
        else
          {[buffer: {:output, %Buffer{payload: payload}}], new_state}
        end
      end
    end

    spec =
      child(:source, %Source{
        output: {initial_state, generator},
        stream_format: %Packet{type: :custom_packets}
      })
      |> child(:depayloader, %Depayloader{packets_per_frame: 5})
      |> child(:sink, Sink)

    pipeline = Pipeline.start_link_supervised!(spec: spec)
    assert_start_of_stream(pipeline, :sink)

    assert_sink_buffer(pipeline, :sink, %Buffer{payload: "Hello! How are you?"})

    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 2000)
    Pipeline.terminate(pipeline)
  end

  test "Depayloader should assemble the packets and form a frame" do
    {[], state} = Depayloader.handle_init(nil, %Depayloader{packets_per_frame: 5})

    {[], state} =
      Depayloader.handle_buffer(
        :input,
        %Buffer{payload: "[frameid:1s][timestamp:1]Hello! "},
        nil,
        state
      )

    {[], state} =
      Depayloader.handle_buffer(
        :input,
        %Buffer{payload: "[frameid:1][timestamp:1]How are"},
        nil,
        state
      )

    {actions, _state} =
      Depayloader.handle_buffer(
        :input,
        %Buffer{payload: "[frameid:1e][timestamp:1] you?"},
        nil,
        state
      )

    [buffer: {:output, buffer}] = actions
    assert buffer.payload == "Hello! How are you?"
  end
end
