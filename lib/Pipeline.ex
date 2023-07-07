defmodule Basic.Pipeline do
  use Membrane.Pipeline
  import Membrane.ChildrenSpec
  import Membrane.Pipeline

  @impl true
  def handle_init(_context, options) do
    {[], %{}}
  end

  @impl true
  def handle_setup(_context, state) do
    structure = [
      child(:input1, %Basic.Elements.Source{location: "input.A.txt"})
      |> child(:ordering_buffer1, Basic.Elements.OrderingBuffer)
      |> child(:depayloader1, %Basic.Elements.Depayloader{packets_per_frame: 4}),

      child(:input2, %Basic.Elements.Source{location: "input.B.txt"})
      |> child(:ordering_buffer2, Basic.Elements.OrderingBuffer)
      |> child(:depayloader2, %Basic.Elements.Depayloader{packets_per_frame: 4}),

      child(:mixer, Basic.Elements.Mixer)
      |> child(:output, %Basic.Elements.Sink{location: "output.txt"}),

      get_child(:depayloader1) |> via_in(:first_input) |> get_child(:mixer),
      get_child(:depayloader2) |> via_in(:second_input) |> get_child(:mixer)
    ]

    {[spec: structure], %{}}
  end

end
