defmodule Basic.Pipeline do
  @moduledoc """
  A module providing the pipeline, which aggregates and links the elements.
  """
  use Membrane.Pipeline
  import Membrane.ChildrenSpec

  @impl true
  def handle_init(_context, _options) do
    {[], %{}}
  end

  @impl true
  def handle_setup(_context, _state) do
    structure = [
      child(:mixer, Basic.Elements.Mixer)
      |> child(:output, %Basic.Elements.Sink{location: "output.txt"}),
      child(:bin1, %Basic.Bin{input_filename: "input.A.txt"})
      |> via_in(:first_input)
      |> get_child(:mixer),
      child(:bin2, %Basic.Bin{input_filename: "input.B.txt"})
      |> via_in(:second_input)
      |> get_child(:mixer)
    ]

    {[spec: structure], %{}}
  end
end
