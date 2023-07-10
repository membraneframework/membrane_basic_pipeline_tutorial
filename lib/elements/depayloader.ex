defmodule Basic.Elements.Depayloader do
  @moduledoc """
  Element responsible for assembling the frames out of ordered packets.
  """
  use Membrane.Filter
  alias Basic.Formats.{Packet, Frame}

  def_options packets_per_frame: [
                spec: pos_integer,
                description:
                  "Positive integer, describing how many packets form a single frame. Used to demand the proper number of packets while assembling the frame."
              ]


  def_input_pad :input,
                [
                  demand_unit: :buffers,
                  accepted_format: %Packet{type: :custom_packets}
                ]

  def_output_pad :output,
                 [
                   accepted_format: %Frame{encoding: :utf8}
                 ]

  @impl true
  def handle_init(_context, options) do
    {[],
      %{
        frame: [],
        packets_per_frame: options.packets_per_frame
      }
    }
  end

  @impl true
  def handle_stream_format(:input, _stream_format, _context, state) do
    {[stream_format: {:output, %Frame{encoding: :utf8}}], state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _context, state) do
    {[demand: {:input, size * state.packets_per_frame}], state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    packet = buffer.payload

    regex =
      ~r/^\[frameid\:(?<frame_id>\d+(?<type>[s|e]*))\]\[timestamp\:(?<timestamp>\d+)\](?<data>.*)$/

    %{"data" => data, "frame_id" => _frame_id, "type" => type, "timestamp" => timestamp} =
      Regex.named_captures(regex, packet)

    frame = [data | state.frame]

    if type == "e" do
      buffer = %Membrane.Buffer{
        payload: prepare_frame(frame),
        pts: String.to_integer(timestamp)
      }
      {[buffer: {:output, buffer}], %{state | frame: []}}
    else
      {[], %{state | frame: frame}}
    end
  end

  defp prepare_frame(frame) do
    frame |> Enum.reverse() |> Enum.join("")
  end
end
