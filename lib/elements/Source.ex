defmodule Basic.Elements.Source do
  use Membrane.Source
  alias Membrane.Buffer

  def_options location: [type: :string, description: "Path to the file"],
              range_start: [type: :integer, spec: pos_integer, description: "Number of the line from which the source starts reading"],
              range_end: [type: :integer, spec: pos_integer, description: "Number of the line to which the source reads"]

  def_output_pad :output, caps: :any

  @impl true
  def handle_init(%__MODULE__{location: location, range_start: range_start, range_end: range_end}) do
    {:ok,
     %{
       location: location,
       range_start: range_start,
       range_end: range_end,
       content: nil
     }}
  end

  @impl true
  def handle_stopped_to_prepared(_ctx, %{location: location, range_start: range_start, range_end: range_end} = state) do
    raw_file_binary = File.read!(location)
    split_string = String.split(raw_file_binary, "\n")
    content = split_string |> Enum.slice(range_start, range_start+range_end)
    segment_ids_range = Enum.to_list(0..length(content)-1)
    content_with_segment_ids = Enum.zip(segment_ids_range, content)
    state = %{state | content: content_with_segment_ids}
    {:ok, state}
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
    chosen = Enum.random(content)
    content = content |> Enum.filter(fn line -> line != chosen end)
    state = %{state | content: content}

    {partial_result, state} = supply_demand(size-1, state)
    result = [ chosen | partial_result ]
    {result, state}
  end

end
