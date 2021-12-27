defmodule Basic.Elements.Decoder do
  use Membrane.Filter

  def_input_pad :input, demand_unit: :buffers, caps: :any
  def_output_pad :output, caps: :any
  def_options x: [type: :integer, spec: pos_integer, description: "test"]

  @impl true
  def handle_demand(_ref, size, _unit, _ctx, state) do
    {{:ok, demand: {Pad.ref(:input), size}}, state}
  end

  @impl true
  def handle_init(_options) do
    {:ok,
    %{
      ordered_frames_list: []
    }}
  end

  @impl true
  def handle_process(:input, %{payload: payload}, _context, %{ordered_frames_list: ordered_frames_list}=state) do

    ordered_frames_list = do_handle_process(payload, ordered_frames_list)
    state = Map.update!(state, :ordered_frames_list, fn _ -> ordered_frames_list end)
    ready_frames_sequence = get_ready_frames_sequence(ordered_frames_list, [])
    buffer = %Membrane.Buffer{payload: ready_frames_sequence}
    {{:ok, buffer: {:output, buffer}}, state}
  end

  defp get_ready_frames_sequence([], acc) do
    acc
  end

  defp get_ready_frames_sequence(ordered_frames_list, acc) do
    [{first_id, first_data} | [{second_id, second_data} | rest]] = ordered_frames_list
    if first_id+1==second_id do
      get_ready_frames_sequence([{second_id, second_data} | rest], [acc | first_data])
    else
      [acc | first_data]
    end
  end

  def do_handle_process([], ordered_frames_list) do
    ordered_frames_list
  end

  def do_handle_process([ {frame_id, frame} | rest], ordered_frames_list) do
    ordered_frames_list = [{frame_id, frame} | ordered_frames_list]
    ordered_frames_list = ordered_frames_list |> Enum.sort()
    do_handle_process(rest, ordered_frames_list)
  end
end
