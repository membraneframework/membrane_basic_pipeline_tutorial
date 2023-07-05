defmodule Basic.Elements.Sink do
  use Membrane.Sink
  alias Basic.Formats.Frame

  def_options location: [
                spec: String.t,
                description: "Path to the file"
              ]

  def_input_pad :input,
                [
                  demand_unit: :buffers,
                  accepted_format: _any
                ]

  @impl true
  def handle_init(_context, options) do
    {[],
      %{location: options.location}
    }
  end

  @impl true
  def handle_playing(_context, state) do
    {[
      demand: {:input, 10}
    ], state}
  end

  @impl true
  def handle_write(:input, buffer, _context, state) do
    File.write!(state.location, buffer.payload <> "\n", [:append])
    {[demand: {:input, 10}], state}
  end
end
