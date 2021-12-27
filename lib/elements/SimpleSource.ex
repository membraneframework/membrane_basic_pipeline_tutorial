defmodule Basic.Elements.SimpleSource do
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
  def handle_demand(:output, 0, :buffers, _ctx, _state), do: []

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, %{content: content}=state) do
    if  length(content) >= size do
      if length(content)==0 do
        {{:ok, end_of_stream: :output}, state}
      else
        {result, state} = supply_demand(size, state)
        action = [buffer: {:output, %Buffer{payload: result}}]
        {{:ok, action}, state}
      end
    else
      {result, state} = supply_demand(length(content), state)
      action = [buffer: {:output, %Buffer{payload: result}}]
      {{:ok, action}, state}
    end
  end



  defp supply_demand(0, state) do
    {[], state}
  end

  defp supply_demand(size, %{content: content} = state) do
    [chosen|rest] = content
    content = rest
    state = %{state | content: content}
    {partial_result, state} = supply_demand(size-1, state)
    result = [ chosen | partial_result ]
    {result, state}
  end

end
