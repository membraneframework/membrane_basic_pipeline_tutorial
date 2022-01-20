defmodule Basic.Pipeline do
  @moduledoc """
  A module providing the pipeline, which aggregates and links the elements.
  """
  use Membrane.Pipeline

  @impl true
  def handle_init(_opts) do
    children = %{
      input1: %Basic.Elements.Source{location: "input1.txt"},
      ordering_buffer1: Basic.Elements.OrderingBuffer,
      depayloader1: %Basic.Elements.Depayloader{packets_per_frame: 5},
      input2: %Basic.Elements.Source{location: "input2.txt"},
      ordering_buffer2: Basic.Elements.OrderingBuffer,
      depayloader2: %Basic.Elements.Depayloader{packets_per_frame: 5},
      mixer: Basic.Elements.Mixer,
      output: %Basic.Elements.Sink{location: "output.txt"}
    }

    links = [
      link(:input1) |> to(:ordering_buffer1) |> to(:depayloader1),
      link(:input2) |> to(:ordering_buffer2) |> to(:depayloader2),
      link(:depayloader1) |> via_in(:first_input) |> to(:mixer),
      link(:depayloader2) |> via_in(:second_input) |> to(:mixer),
      link(:mixer) |> to(:output)
    ]

    spec = %ParentSpec{children: children, links: links}

    {{:ok, spec: spec}, %{}}
  end
end
