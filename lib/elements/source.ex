defmodule Basic.Elements.Source do
  use Membrane.Source
  alias Membrane.Buffer
  alias Basic.Formats.Packet

  def_options location: [
                spec: String.t,
                description: "Path to the file"
              ]

  def_output_pad :output,
                 [
                   accepted_format: %Packet{type: :custom_packets},
                   mode: :pull
                 ]

  @impl true
  def handle_init(_context, options) do
    {[],
      %{
        location: options.location,
        content: nil
      }
    }
  end

  @impl true
  def handle_playing(_context, state) do
    content = File.read!(state.location)
    |> String.split("\n")

    new_state = %{state | content: content}
    {[
      stream_format: {:output, %Packet{type: :custom_packets}},
    ], new_state}
  end


  @impl true
  def handle_demand(:output, _size, :buffers, _context, state) do
    if state.content == [] do
      {[end_of_stream: :output], state}
    else
      [first_packet | rest] = state.content
      new_state = %{state | content: rest}
      actions = [
        buffer: {:output, %Buffer{payload: first_packet}},
        redemand: :output
      ]
      {actions, new_state}
    end
  end
end
