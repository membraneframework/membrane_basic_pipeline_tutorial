defmodule Basic.Elements.Depayloader do
  use Membrane.Filter

  def_input_pad :input, demand_unit: :buffers, caps: {Basic.Format, type: :ordered}
  def_output_pad :output, caps: {Basic.Format, type: :frame}
  def_options demand_factor: [type: :integer, spec: pos_integer, description: "Demand Factor"]



  @impl true
  def handle_init(%__MODULE__{demand_factor: demand_factor}) do
    {:ok,
     %{
       frame: [],
       demand_factor: demand_factor
     }}
  end

  @impl true
  def handle_caps(_pad, _caps, _context, state) do
    caps = %Basic.Format{type: :frame}
    {{:ok, caps: {:output, caps} }, state}
  end

  @impl true
  def handle_demand(_ref, size, _unit, _ctx, %{demand_factor: demand_factor} = state) do
    {{:ok, demand: {Pad.ref(:input), size*demand_factor}}, state}
  end

  @impl true
  def handle_process(_ref, %Membrane.Buffer{payload: payload}, _ctx, state) do
    add_line(payload, state)
  end

  def handle_other({:frame_ready, {timestamp, frame}}, _context, state) do
    buffer = %Membrane.Buffer{payload: [{timestamp, frame}]}
    {{:ok, buffer: {:output, buffer}}, state}
  end

  defp add_line(line, %{frame: frame}=state) do
    regex = ~r/^\[frameid\:(?<frame_id>\d+(?<type>[s|e]*))\](?<data>.*)$/
    %{"data"=>data, "frame_id"=>_frame_id, "type"=>type} = Regex.named_captures(regex, line)
    case type do
      "e" ->
        frame = [data | frame]
        actions = prepare_frame(Enum.reverse(frame))
        state = Map.update!(state, :frame, fn _ -> [] end)
        {{:ok, actions}, state}
      _  ->
        frame = [data | frame]
        state = Map.update!(state, :frame, fn _ -> frame end)
        {{:ok, redemand: :output}, state}
    end
  end

  defp prepare_frame(frame) do
    regex = ~r/^\[timestamp\:(?<timestamp>\d+)\](?<data>.*)$/
    lines_without_frameid = for line <- frame do
      %{"data"=>data, "timestamp"=>timestamp} = Regex.named_captures(regex, line)
      {timestamp, data}
    end
    {timestamp, _} = Enum.at(lines_without_frameid, 0)
    lines_without_timestamp = Enum.map(lines_without_frameid, fn {_timestamp, data} -> data end)

    frame = lines_without_timestamp |> Enum.join(" ")
    buffer = %Membrane.Buffer{payload: frame, pts: String.to_integer(timestamp)}
    [buffer: {:output, buffer}]
  end

end
