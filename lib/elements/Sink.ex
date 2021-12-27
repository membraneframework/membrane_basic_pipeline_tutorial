defmodule Basic.Elements.Sink do
  use Membrane.Sink
  alias Membrane.Buffer

  def_options location: [type: :string, description: "Path to the file"]

  def_input_pad :input, demand_unit: :buffers, caps: :any


  @impl true
  def handle_init(%__MODULE__{location: location}) do
    {:ok,
     %{
       location: location
     }}
  end

  @impl true
  def handle_stopped_to_prepared(_context, state) do
    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, demand: {:input, 2}}, state}
  end

  @impl true
  def handle_prepared_to_stopped(_context, state) do
    {:ok, state}
  end

  @impl true
  def handle_write(:input, %Buffer{payload: payload}, _ctx, %{location: location}=state) do
    for text <- payload, do: File.write!(location, text<>"\n", [:append])
    {{:ok, demand: {:input, 10}}, state}

  end

end
