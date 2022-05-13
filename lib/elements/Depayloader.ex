defmodule Basic.Elements.Depayloader do
  @moduledoc """
  Element responsible for assembling the frames out of ordered packets.
  """
  use Membrane.Filter
  alias Basic.Formats.{Frame, Packet}

  def_input_pad(:input, demand_unit: :buffers, caps: {Packet, type: :custom_packets})

  def_output_pad(:output, caps: {Frame, encoding: :utf8})

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
    caps = %Frame{encoding: :utf8}
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_demand(_ref, size, _unit, _ctx, state) do
    {{:ok, demand: {Pad.ref(:input), size * state.packets_per_frame}}, state}
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
        frame = prepare_frame(frame)
        state = Map.put(state, :frame, [])
        buffer = %Membrane.Buffer{payload: frame, pts: String.to_integer(timestamp)}
        {{:ok, [buffer: {:output, buffer}]}, state}

      _ ->
        state = Map.put(state, :frame, frame)
        {:ok, state}
    end
  end

  defp prepare_frame(frame) do
    frame |> Enum.reverse() |> Enum.join("")
  end
end
