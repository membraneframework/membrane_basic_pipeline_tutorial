defmodule Basic.Elements.Source do
  use Membrane.Source
  alias Membrane.Buffer

  def_options location: [type: :string, description: "Path to the file"]

  def_output_pad :output, caps: {Basic.Format, type: :fragmented}

  @impl true
  def handle_init(%__MODULE__{location: location}) do
    {:ok,
     %{
       location: location,
       content: nil
     }}
  end

  @impl true
  def handle_stopped_to_prepared(_ctx, %{location: location} = state) do
    raw_file_binary = File.read!(location)
    content = String.split(raw_file_binary, "\n")
    state = %{state | content: content}
    { {:ok, [caps: {:output, %Basic.Format{type: :fragmented}}  ] }, state}
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    state = %{state | content: nil}
    {:ok, state}
  end

  @impl true
  def handle_demand(:output, 0, :buffers, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, %{content: content}=state) do
    if content == [] do
      {{:ok, end_of_stream: :output}, state}
    else
      [chosen|rest] = content
      state = %{state | content: rest}
      action = [buffer: {:output, %Buffer{payload: chosen}}, redemand: :output]
      action = if size > 1, do: action++[redemand: :output], else: action
      {{:ok, action}, state}
    end
  end

end
