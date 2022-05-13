defmodule Basic.Elements.Sink do
  @moduledoc """
  An element writing the data to the text file.
  """

  use Membrane.Sink

  def_options(location: [type: :string, description: "Path to the file"])

  def_input_pad(:input, demand_unit: :buffers, caps: :any)

  @impl true
  def handle_init(options) do
    {:ok,
     %{
       location: options.location
     }}
  end

  @impl true
  def handle_stopped_to_prepared(_context, state) do
    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, demand: {:input, 10}}, state}
  end

  @impl true
  def handle_prepared_to_stopped(_context, state) do
    {:ok, state}
  end

  @impl true
  def handle_write(:input, buffer, _ctx, state) do
    File.write!(state.location, buffer.payload <> "\n", [:append])
    {{:ok, demand: {:input, 10}}, state}
  end
end
