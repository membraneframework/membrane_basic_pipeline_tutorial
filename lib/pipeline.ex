defmodule Basic.Pipeline do
  @moduledoc """
  A module providing the pipeline, which aggregates and links the elements.
  """
  use Membrane.Pipeline
  alias Membrane.Pad

  @impl true
  def handle_init(_opts) do
    children = %{
      input1: %Basic.Elements.Source{location: "input.A.txt"},
      ordering_buffer1: Basic.Elements.OrderingBuffer,
      depayloader1: %Basic.Elements.Depayloader{packets_per_frame: 4},

      input2: %Basic.Elements.Source{location: "input.B.txt"},
      ordering_buffer2: Basic.Elements.OrderingBuffer,
      depayloader2: %Basic.Elements.Depayloader{packets_per_frame: 4},

      input3: %Basic.Elements.Source{location: "input.C.txt"},
      ordering_buffer3: Basic.Elements.OrderingBuffer,
      depayloader3: %Basic.Elements.Depayloader{packets_per_frame: 4},

      mixer: Basic.Elements.Mixer,
      output: %Basic.Elements.Sink{location: "output.txt"}
    }

    links = [
      link(:input1) |> to(:ordering_buffer1) |> to(:depayloader1),
      link(:input2) |> to(:ordering_buffer2) |> to(:depayloader2),
      link(:input3) |> to(:ordering_buffer3) |> to(:depayloader3),
      link(:depayloader1) |> via_in(Pad.ref(:input, :first)) |> to(:mixer),
      link(:depayloader2) |> via_in(Pad.ref(:input, :second)) |> to(:mixer),
      link(:depayloader3) |> via_in(Pad.ref(:input, :third)) |> to(:mixer),
      link(:mixer) |> to(:output)
    ]

    spec = %ParentSpec{children: children, links: links}

    {{:ok, spec: spec}, %{}}
  end
end
