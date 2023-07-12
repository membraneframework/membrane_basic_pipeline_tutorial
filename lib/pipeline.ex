defmodule Basic.Pipeline do
  @moduledoc """
  A module providing the pipeline, which aggregates and links the elements.
  """
  use Membrane.Pipeline
  import Membrane.ChildrenSpec
  alias Membrane.Pad

  @impl true
  def handle_init(_context, _options) do
    structure = [
      child(:input1, %Basic.Elements.Source{location: "input.A.txt"})
      |> child(:ordering_buffer1, Basic.Elements.OrderingBuffer)
      |> child(:depayloader1, %Basic.Elements.Depayloader{packets_per_frame: 4})
      |> via_in(Pad.ref(:input, :first))
      |> child(:mixer, Basic.Elements.Mixer)
      |> child(:output, %Basic.Elements.Sink{location: "output.txt"}),
      child(:input2, %Basic.Elements.Source{location: "input.B.txt"})
      |> child(:ordering_buffer2, Basic.Elements.OrderingBuffer)
      |> child(:depayloader2, %Basic.Elements.Depayloader{packets_per_frame: 4})
      |> via_in(Pad.ref(:input, :second))
      |> get_child(:mixer),
      child(:input3, %Basic.Elements.Source{location: "input.C.txt"})
      |> child(:ordering_buffer3, Basic.Elements.OrderingBuffer)
      |> child(:depayloader3, %Basic.Elements.Depayloader{packets_per_frame: 4})
      |> via_in(Pad.ref(:input, :third))
      |> get_child(:mixer)
    ]

    {[spec: structure], %{}}
  end
end
