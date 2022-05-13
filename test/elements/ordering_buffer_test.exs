defmodule OrderingBufferTest do
  use ExUnit.Case
  alias Basic.Elements.OrderingBuffer
  alias Membrane.Buffer

  @initial_state %{
    ordered_packets: [],
    last_sent_seq_id: 0
  }

  doctest Basic.Elements.OrderingBuffer

  test "Ordering buffer should order the incoming packets" do
    {{:ok, actions}, state} =
      OrderingBuffer.handle_process(
        :input,
        %Buffer{payload: "[seq:2]How are"},
        nil,
        @initial_state
      )

    assert actions == [redemand: :output]

    {{:ok, actions}, state} =
      OrderingBuffer.handle_process(:input, %Buffer{payload: "[seq:3] you?"}, nil, state)

    assert actions == [redemand: :output]

    {{:ok, actions}, state} =
      OrderingBuffer.handle_process(:input, %Buffer{payload: "[seq:7]Something else"}, nil, state)

    assert actions == [redemand: :output]

    {{:ok, actions}, state} =
      OrderingBuffer.handle_process(:input, %Buffer{payload: "[seq:1]Hello! "}, nil, state)

    [buffer: {:output, buffers}] = actions
    concatenated = Enum.map(buffers, & &1.payload) |> Enum.join("")
    assert concatenated == "Hello! How are you?"
    assert state.ordered_packets == [{7, %Buffer{payload: "Something else"}}]
    assert state.last_sent_seq_id == 3
  end
end
