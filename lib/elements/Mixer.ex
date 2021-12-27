defmodule Basic.Elements.Mixer do
  use Membrane.Filter

  def_input_pad :first_input, demand_unit: :buffers, caps: {Basic.Format, type: :frame}
  def_input_pad :second_input, demand_unit: :buffers, caps: {Basic.Format, type: :frame}
  def_output_pad :output, caps: {Basic.Format, type: :frames_sequence}
  def_options demand_factor: [type: :integer, spec: pos_integer, description: "Demand factor"]

  @impl true
  def handle_demand(_ref, size, _unit, _ctx, %{demand_factor: demand_factor} = state) do
    {{:ok, [demand: {Pad.ref(:first_input), demand_factor*div(size, 2)}, demand: {Pad.ref(:second_input), demand_factor*div(size, 2)}]}, state}
  end

  @impl true
  def handle_init(%__MODULE__{demand_factor: demand_factor}) do
    {:ok,
    %{
      ordered_frames: [],
      last_sent_frame_timestamp: 0,
      demand_factor: demand_factor
    }}
  end

  @impl true
  def handle_caps(_pad, _caps, _context, state) do
    caps = %Basic.Format{type: :frames_sequence}
    {{:ok, caps: {:output, caps} }, state}
  end

  @impl true
  def handle_process(_pad, %{payload: payload}, _context, %{ordered_frames: ordered_frames, last_sent_frame_timestamp: last_sent_frame_timestamp}=state) do
    ordered_frames = do_handle_process(payload, ordered_frames)
    state = Map.update!(state, :ordered_frames, fn _ -> ordered_frames end)
    {timestamp, _frame} = Enum.at(ordered_frames, 0)
    if last_sent_frame_timestamp+1==timestamp do
      reversed_ready_frames_sequence = get_ready_frames_sequence(ordered_frames, [])
      ordered_frames = Enum.slice(ordered_frames, Range.new(length(reversed_ready_frames_sequence), length(ordered_frames)))

      {last_timestamp, _frame} = Enum.at(reversed_ready_frames_sequence, 0)
      state = Map.update!(state, :ordered_frames, fn _ -> ordered_frames end)
      state = Map.update!(state, :last_sent_frame_timestamp, fn _ -> last_timestamp end)
      ready_frames_sequence = Enum.reverse(reversed_ready_frames_sequence)
      ready_frames_sequence = Enum.map(ready_frames_sequence, fn {_timestamp, frame}-> frame end)
      buffer = %Membrane.Buffer{payload: ready_frames_sequence}
      {{:ok, buffer: {:output, buffer}}, state}
    else
      {{:ok, redemand: :output}, state}
    end

  end

  defp get_ready_frames_sequence([], acc) do
    acc
  end

  defp get_ready_frames_sequence([{first_timestamp, _first_data}=first_frame| [{second_timestamp, second_data} | rest]] , acc) when first_timestamp+1==second_timestamp do
      get_ready_frames_sequence([{second_timestamp, second_data} | rest], [first_frame | acc])
  end

  defp get_ready_frames_sequence([frame | _rest], acc) do
    [ frame| acc ]
  end

  def do_handle_process([], acc) do
    acc
  end

  def do_handle_process([ {timestamp, frame} | rest], ordered_frames) do
    ordered_frames = [ {timestamp, frame} | ordered_frames]
    ordered_frames = ordered_frames |> Enum.sort()
    do_handle_process(rest, ordered_frames)
  end

end
