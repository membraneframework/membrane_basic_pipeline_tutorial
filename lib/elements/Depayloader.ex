defmodule Basic.Elements.Depayloader do
  @moduledoc """
  Element responsible for assembling the frames out of ordered packets.
  """
  use Membrane.Filter

  def_input_pad(:input, demand_unit: :buffers, caps: {Basic.Formats.Packet, type: :custom_packets})

  def_output_pad(:output, caps: {Basic.Formats.Frame, encoding: :utf8})

  def_options(
    packets_per_frame: [
      type: :integer,
      spec: pos_integer,
      description:
        "Positive integer, describing how many packets form a single frame. Used to demand for the proper number of packets while assembling the frame."
    ]
  )

  @impl true
  def handle_init(options) do
    {:ok,
     %{
       frame: [],
       packets_per_frame: options.packets_per_frame
     }}
  end

  @impl true
  def handle_caps(_pad, _caps, _context, state) do
    caps = %Basic.Formats.Frame{encoding: :utf8}
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_demand(_ref, size, _unit, _ctx, state) do
    {{:ok, demand: {Pad.ref(:input), size}}, state}
  end

  @impl true
  def handle_process(_ref, buffer, _ctx, state) do
    packet = buffer.payload

    regex =
      ~r/^\[frameid\:(?<frame_id>\d+(?<type>[s|e]*))\]\[timestamp\:(?<timestamp>\d+)\](?<data>.*)$/

    %{"data" => data, "frame_id" => _frame_id, "type" => type, "timestamp" => timestamp} =
      Regex.named_captures(regex, packet)

    frame = [data | state.frame]

    case type do
      "e" ->
        actions = prepare_frame(Enum.reverse(frame), timestamp)
        state = Map.put(state, :frame, [])
        {{:ok, actions}, state}

      _ ->
        state = Map.put(state, :frame, frame)
        {:ok, state}
    end
  end

  defp prepare_frame(frame, timestamp) do
    frame = frame |> Enum.join("")
    buffer = %Membrane.Buffer{payload: frame, pts: String.to_integer(timestamp)}
    [buffer: {:output, buffer}]
  end
end
