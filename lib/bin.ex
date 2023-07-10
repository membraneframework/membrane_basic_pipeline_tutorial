defmodule Basic.Bin do
  use Membrane.Bin
  alias Basic.Formats.Frame
  import Membrane.ChildrenSpec

  def_options input_filename: [
                spec: String.t(),
                description: "Input file for conversation."
              ]

  def_output_pad :output,
                 [
                  demand_unit: :buffers,
                  accepted_format: %Frame{encoding: :utf8}
                 ]

  def handle_init(_context, options) do
    structure = [
      child(:input, %Basic.Elements.Source{location: options.input_filename})
      |> child(:ordering_buffer, Basic.Elements.OrderingBuffer)
      |> child(:depayloader, %Basic.Elements.Depayloader{packets_per_frame: 4})
      |> bin_output(:output)
    ]

    {[spec: structure], %{}}
  end
  
end
