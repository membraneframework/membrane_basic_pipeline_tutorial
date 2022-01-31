defmodule DepayloaderTest do
  use ExUnit.Case
  alias Basic.Elements.Depayloader
  alias Membrane.Buffer

  @initial_state %{
    frame: [],
    packets_per_frame: 5
  }

  doctest Basic.Elements.OrderingBuffer

  test "Depayloader should assemble the packets and form a frame" do
    {:ok, state} = Depayloader.handle_process(:input, %Buffer{payload: "[frameid:1s][timestamp:1]Hello! "}, nil, @initial_state)
    {:ok, state} = Depayloader.handle_process(:input, %Buffer{payload: "[frameid:1][timestamp:1]How are"}, nil, state)
    {{:ok, actions}, _state} = Depayloader.handle_process(:input, %Buffer{payload: "[frameid:1e][timestamp:1] you?"}, nil, state)
    [buffer: {:output, buffer}] = actions
    assert buffer.payload == "Hello! How are you?"
  end

end
