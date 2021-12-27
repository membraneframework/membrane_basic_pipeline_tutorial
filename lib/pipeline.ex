defmodule Basic.Pipeline do

  use Membrane.Pipeline

  @impl true
  def handle_init(_opts) do
    children = %{
      input1: %Basic.Elements.SimpleSource{location: "input1.txt"},
      jitter_buffer1: %Basic.Elements.JitterBuffer{demand_factor: 1},
      depayloader1: %Basic.Elements.Depayloader{demand_factor: 5},

      input2: %Basic.Elements.SimpleSource{location: "input2.txt"},
      jitter_buffer2: %Basic.Elements.JitterBuffer{demand_factor: 1},
      depayloader2: %Basic.Elements.Depayloader{demand_factor: 5},

      mixer: %Basic.Elements.Mixer{demand_factor: 1},
      output: %Basic.Elements.Sink{location: "output.txt"}
    }

    links = [
      link(:input1) |> to(:jitter_buffer1) |> to(:depayloader1),
      link(:input2) |> to(:jitter_buffer2) |> to(:depayloader2),
      link(:depayloader1) |> via_in(:first_input) |> to(:mixer),
      link(:depayloader2) |> via_in(:second_input) |> to(:mixer),
      link(:mixer) |> to(:output)
    ]

    spec = %ParentSpec{children: children, links: links}

    {{:ok, spec: spec}, %{}}
  end

end
