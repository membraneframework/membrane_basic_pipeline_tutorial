defmodule Basic.Elements.OrderingBuffer do
  use Membrane.Filter

  def_input_pad :input, demand_unit: :buffers, caps: {Basic.Format, type: :fragmented}
  def_output_pad :output, caps: {Basic.Format, type: :ordered}
  def_options demand_factor: [type: :integer, spec: pos_integer, description: "Demand Factor"]

  @impl true
  def handle_demand(_ref, size, _unit, _ctx, %{demand_factor: demand_factor}=state) do
    {{:ok, demand: {Pad.ref(:input), demand_factor*size}}, state}
  end

  @impl true
  def handle_caps(_pad, _caps, _context, state) do
    caps = %Basic.Format{type: :ordered}
    {{:ok, caps: {:output, caps} }, state}
  end

  @impl true
  def handle_init(%__MODULE__{demand_factor: demand_factor}) do
    {:ok,
    %{
      ordered_packets: [],
      last_processed_seq_id: 0,
      demand_factor: demand_factor
    }}
  end

  @impl true
  def handle_process(:input, %{payload: payload}, _context, %{ordered_packets: ordered_packets, last_processed_seq_id: last_processed_seq_id}=state) do
    packet = unzip_packet(payload)
    ordered_packets = [packet | ordered_packets] |> Enum.sort()
    state = Map.update!(state, :ordered_packets, fn _ -> ordered_packets end)
    {last_seq_id, _} = Enum.at(ordered_packets, 0)
    if last_processed_seq_id+1==last_seq_id do
      reversed_ready_packets_sequence = get_ready_packets_sequence(ordered_packets, [])
      {last_processed_seq_id, _} = Enum.at(reversed_ready_packets_sequence, 0)
      ordered_packets = Enum.slice(ordered_packets, Range.new(length(reversed_ready_packets_sequence), length(ordered_packets)))
      state = Map.update!(state, :ordered_packets, fn _ -> ordered_packets end)
      state = Map.update!(state, :last_processed_seq_id, fn _ -> last_processed_seq_id end)
      ready_packets_sequence = Enum.reverse(reversed_ready_packets_sequence)
      ready_packets_sequence = Enum.map(ready_packets_sequence, fn {_seq_id, data} -> data end)
      buffers = ready_packets_sequence |> Enum.map(fn packet -> %Membrane.Buffer{payload: packet} end)
      {{:ok, buffer: {:output, buffers}}, state}
    else
      {{:ok, redemand: :output}, state}
    end

  end

  defp get_ready_packets_sequence([], acc) do
    acc
  end

  defp get_ready_packets_sequence([{first_id, _first_data}=first_seq | [{second_id, second_data} | rest]] , acc) when first_id+1==second_id do
      get_ready_packets_sequence([{second_id, second_data} | rest], [first_seq | acc])
  end

  defp get_ready_packets_sequence([first_seq | _rest], acc) do
    [ first_seq | acc ]
  end

  defp unzip_packet(packet) do
    regex = ~r/^\[seq\:(?<seq_id>\d+)\](?<data>.*)$/
    %{"data"=>data, "seq_id"=>seq_id} = Regex.named_captures(regex, packet)
    {String.to_integer(seq_id), data}
  end
end
