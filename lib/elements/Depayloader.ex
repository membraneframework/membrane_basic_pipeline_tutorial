defmodule Basic.Elements.Depayloader do
  use Membrane.Filter

  def_input_pad(:input, demand_unit: :buffers, caps: {Basic.Formats.Packet, type: :custom_packets})

  def_output_pad(:output, caps: {Basic.Formats.Frame, encoding: :utf8})
  def_options(demand_factor: [type: :integer, spec: pos_integer, description: "Positive integer, describing how much input buffers should be requested per each output buffer"])

  @impl true
  def handle_init(options) do
    {:ok,
     %{
       frame: [],
       demand_factor: options.demand_factor
     }}
  end

  @impl true
  def handle_caps(_pad, _caps, _context, state) do
    caps = %Basic.Formats.Frame{encoding: :utf8}
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_demand(_ref, size, _unit, _ctx, state) do
    {{:ok, demand: {Pad.ref(:input), size * state.demand_factor}}, state}
  end

  @impl true
  def handle_process(_ref, buffer, _ctx, state) do
    packet = buffer.payload
    regex = ~r/^\[frameid\:(?<frame_id>\d+(?<type>[s|e]*))\]\[timestamp\:(?<timestamp>\d+)\](?<data>.*)$/

    %{"data" => data, "frame_id" => _frame_id, "type" => type, "timestamp"=>timestamp} =
      Regex.named_captures(regex, packet)

    frame = [data | state.frame]
    case type do
      "e" ->
        actions = prepare_frame(Enum.reverse(frame), timestamp)
        state = Map.put(state, :frame, [])
        {{:ok, actions}, state}

      _ ->
        state = Map.put(state, :frame, frame)
        {{:ok, redemand: :output}, state}
    end
  end

  defp prepare_frame(frame, timestamp) do
    IO.puts("#{inspect(frame)}, #{timestamp}")
    frame = frame |> Enum.join(" ")
    buffer = %Membrane.Buffer{payload: frame, pts: String.to_integer(timestamp)}
    [buffer: {:output, buffer}]
  end
end
