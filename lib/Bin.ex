defmodule Basic.Bin do
  use Membrane.Bin

  def_output_pad :output,
    demand_unit: :buffers,
    caps: {Basic.Formats.Frame, encoding: :utf8}

  def_options input_filename: [
                type: :string,
                description: "Input file for conversation."
              ]

  @impl true
  def handle_init(options) do
    children = %{
      input: %Basic.Elements.Source{location: options.input_filename},
      ordering_buffer: Basic.Elements.OrderingBuffer,
      depayloader: %Basic.Elements.Depayloader{packets_per_frame: 4}
    }

    links = [
      link(:input) |> to(:ordering_buffer) |> to(:depayloader) |> to_bin_output(:output)
    ]

    spec = %ParentSpec{children: children, links: links}

    {{:ok, spec: spec}, %{}}
  end
end
