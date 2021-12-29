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
      ordered_lines: [],
      last_processed_seq_id: 0,
      demand_factor: demand_factor
    }}
  end

  @impl true
  def handle_process(:input, %{payload: payload}, _context, %{ordered_lines: ordered_lines, last_processed_seq_id: last_processed_seq_id}=state) do
    ordered_lines = do_handle_process(payload, ordered_lines)
    state = Map.update!(state, :ordered_lines, fn _ -> ordered_lines end)
    if ordered_lines == [] do
      {{:ok, redemand: :output}, state}
    else
      {last_seq_id, _} = Enum.at(ordered_lines, 0)
      if last_processed_seq_id+1==last_seq_id do
        reversed_ready_lines_sequence = get_ready_lines_sequence(ordered_lines, [])
        {last_processed_seq_id, _} = Enum.at(reversed_ready_lines_sequence, 0)
        ordered_lines = Enum.slice(ordered_lines, Range.new(length(reversed_ready_lines_sequence), length(ordered_lines)))
        state = Map.update!(state, :ordered_lines, fn _ -> ordered_lines end)
        state = Map.update!(state, :last_processed_seq_id, fn _ -> last_processed_seq_id end)
        ready_lines_sequence = Enum.reverse(reversed_ready_lines_sequence)
        ready_lines_sequence = Enum.map(ready_lines_sequence, fn {_seq_id, data} -> data end)
        buffer = %Membrane.Buffer{payload: ready_lines_sequence}
        {{:ok, buffer: {:output, buffer}}, state}
      else
        {{:ok, redemand: :output}, state}
      end
    end
  end

  defp get_ready_lines_sequence([], acc) do
    acc
  end

  defp get_ready_lines_sequence([{first_id, _first_data}=first_seq | [{second_id, second_data} | rest]] , acc) when first_id+1==second_id do
      get_ready_lines_sequence([{second_id, second_data} | rest], [first_seq | acc])
  end

  defp get_ready_lines_sequence([first_seq | _rest], acc) do
    [ first_seq | acc ]
  end

  def do_handle_process([], acc) do
    acc
  end

  def do_handle_process([ line | rest], ordered_lines) do
    unziped_line = unzip_line(line)
    ordered_lines = [unziped_line | ordered_lines]
    ordered_lines = ordered_lines |> Enum.sort()
    do_handle_process(rest, ordered_lines)
  end

  defp unzip_line(line) do
    regex = ~r/^\[seq\:(?<seq_id>\d+)\](?<data>.*)$/
    %{"data"=>data, "seq_id"=>seq_id} = Regex.named_captures(regex, line)
    {String.to_integer(seq_id), data}
  end
end
