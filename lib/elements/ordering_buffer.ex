defmodule Basic.Elements.OrderingBuffer do
  @moduledoc """
  An element that gathers the packets and puts them in the order, sorted by their sequence id.
  Once the consistent batch of packets (which means - with no packets missing in-between) is completely gathered, it is sent through the output pad.
  """
  use Membrane.Filter
  alias Basic.Formats.Packet

  def_input_pad :input,
    flow_control: :manual,
    demand_unit: :buffers,
    accepted_format: %Packet{type: :custom_packets}

  def_output_pad :output,
    flow_control: :manual,
    accepted_format: %Packet{type: :custom_packets}

  @impl true
  def handle_init(_context, _options) do
    {[],
     %{
       ordered_packets: [],
       last_sent_seq_id: 0
     }}
  end

  @impl true
  def handle_demand(:output, size, _unit, _context, state) do
    {[demand: {:input, size}], state}
  end

  @impl true
  def handle_buffer(:input, buffer, _context, state) do
    packet = unzip_packet(buffer.payload)
    ordered_packets = [packet | state.ordered_packets] |> Enum.sort()
    state = %{state | ordered_packets: ordered_packets}
    [{last_seq_id, _} | _] = ordered_packets

    if state.last_sent_seq_id + 1 == last_seq_id do
      {ready_packets_sequence, ordered_packets_left} =
        get_ready_packets_sequence(ordered_packets, [])

      {last_sent_seq_id, _} = List.last(ready_packets_sequence)

      state = %{
        state
        | ordered_packets: ordered_packets_left,
          last_sent_seq_id: last_sent_seq_id
      }

      ready_buffers = Enum.map(ready_packets_sequence, &elem(&1, 1))

      {[buffer: {:output, ready_buffers}], state}
    else
      {[redemand: :output], state}
    end
  end

  defp get_ready_packets_sequence([], ready_sequence) do
    {Enum.reverse(ready_sequence), []}
  end

  defp get_ready_packets_sequence(
         [first_seq = {first_id, _}, second_seq = {second_id, _} | rest],
         ready_sequence
       )
       when first_id + 1 == second_id do
    get_ready_packets_sequence([second_seq | rest], [first_seq | ready_sequence])
  end

  defp get_ready_packets_sequence([first_seq | rest], ready_sequence) do
    {Enum.reverse([first_seq | ready_sequence]), rest}
  end

  defp unzip_packet(packet) do
    regex = ~r/^\[seq\:(?<seq_id>\d+)\](?<data>.*)$/
    %{"data" => data, "seq_id" => seq_id} = Regex.named_captures(regex, packet)
    {String.to_integer(seq_id), %Membrane.Buffer{payload: data}}
  end
end
