defmodule Basic.Elements.OrderingBuffer do
  @moduledoc """
  An element that gathers the packets and puts them in the order, sorted by their sequence id.
  Once the consistent batch of packets (which means - with no packets missing in-between) is completely gathered, it is sent through the output pad.
  """

  use Membrane.Filter
  alias Basic.Formats.Packet

  def_input_pad(:input, demand_unit: :buffers, caps: {Packet, type: :custom_packets})

  def_output_pad(:output, caps: {Packet, type: :custom_packets})

  @impl true
  def handle_init(_options) do
    {:ok,
     %{
       ordered_packets: [],
       last_sent_seq_id: 0
     }}
  end

  @impl true
  def handle_demand(_ref, size, _unit, _ctx, state) do
    {{:ok, demand: {Pad.ref(:input), size}}, state}
  end

  @impl true
  def handle_process(
        :input,
        buffer,
        _context,
        state
      ) do
    packet = unzip_packet(buffer.payload)
    ordered_packets = [packet | state.ordered_packets] |> Enum.sort()
    state = Map.put(state, :ordered_packets, ordered_packets)
    {last_seq_id, _} = Enum.at(ordered_packets, 0)

    if state.last_sent_seq_id + 1 == last_seq_id do
      {reversed_ready_packets_sequence, ordered_packets} =
        get_ready_packets_sequence(ordered_packets, [])

      [{last_sent_seq_id, _} | _] = reversed_ready_packets_sequence

      state = %{
        state
        | ordered_packets: ordered_packets,
          last_sent_seq_id: last_sent_seq_id
      }

      buffers =
        Enum.reverse(reversed_ready_packets_sequence) |> Enum.map(fn {_seq_id, data} -> data end)

      {{:ok, buffer: {:output, buffers}}, state}
    else
      {{:ok, redemand: :output}, state}
    end
  end

  defp get_ready_packets_sequence([], acc) do
    {acc, []}
  end

  defp get_ready_packets_sequence(
         [{first_id, _first_data} = first_seq | [{second_id, second_data} | rest]],
         acc
       )
       when first_id + 1 == second_id do
    get_ready_packets_sequence([{second_id, second_data} | rest], [first_seq | acc])
  end

  defp get_ready_packets_sequence([first_seq | rest], acc) do
    {[first_seq | acc], rest}
  end

  defp unzip_packet(packet) do
    regex = ~r/^\[seq\:(?<seq_id>\d+)\](?<data>.*)$/
    %{"data" => data, "seq_id" => seq_id} = Regex.named_captures(regex, packet)
    {String.to_integer(seq_id), %Membrane.Buffer{payload: data}}
  end
end
