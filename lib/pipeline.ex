defmodule Basic.Pipeline do
  @moduledoc """
  A module providing the pipeline, which aggregates and links the elements.
  """
  use Membrane.Pipeline

  @impl true
  def handle_init(_opts) do
    children = %{
      bin1: %Basic.Bin{input_filename: "input.A.txt"},
      bin2: %Basic.Bin{input_filename: "input.B.txt"},
      mixer: Basic.Elements.Mixer,
      output: %Basic.Elements.Sink{location: "output.txt"}
    }

    links = [
      link(:bin1) |> via_in(:first_input) |> to(:mixer),
      link(:bin2) |> via_in(:second_input) |> to(:mixer),
      link(:mixer) |> to(:output)
    ]

    spec = %ParentSpec{children: children, links: links}

    {{:ok, spec: spec}, %{}}
  end
end
