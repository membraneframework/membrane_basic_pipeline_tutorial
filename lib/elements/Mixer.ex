defmodule Basic.Elements.Mixer do
  @moduledoc """
  Element responsible for ordering the frames coming from two sources, basing on their timestamps.
  """
  use Membrane.Filter

  def_input_pad(:first_input, demand_unit: :buffers, caps: {Basic.Formats.Frame, encoding: :utf8})

  def_input_pad(:second_input, demand_unit: :buffers, caps: {Basic.Formats.Frame, encoding: :utf8})

  def_output_pad(:output, caps: {Basic.Formats.Frame, encoding: :utf8})

  @impl true
  def handle_init(_options) do
    {:ok,
     %{
       tracks_statuses: %{first_input: :ready, second_input: :ready},
       tracks_buffers: %{first_input: [], second_input: []},
       last_sent_frame_timestamp: 0
     }}
  end

  @impl true
  def handle_demand(_ref, 0, _unit, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_demand(_ref, size, _unit, _ctx, state) do
    {{:ok,
      [
        demand: {:first_input, size},
        demand: {:second_input, size}
      ]}, state}
  end

  @impl true
  def handle_end_of_stream(pad, _context, state) do
    state =
      if Map.get(state.tracks_buffers, pad) == [] do
        Map.put(state, :tracks_statuses, Map.put(state.tracks_statuses, pad, :processed))
      else
        Map.put(state, :tracks_statuses, Map.put(state.tracks_statuses, pad, :stream_ended))
      end

    prepare_buffers(state)
  end

  @impl true
  def handle_process(pad, buffer, _context, state) do
    buffers = Map.get(state.tracks_buffers, pad)
    buffers = [buffer | buffers]
    state = Map.put(state, :tracks_buffers, Map.put(state.tracks_buffers, pad, buffers))
    prepare_buffers(state)
  end

  defp prepare_buffers(state) do
    tracks_buffers =
      Enum.filter(state.tracks_buffers, fn {key, _value} ->
        Map.get(state.tracks_statuses, key) != :processed
      end)

    if tracks_buffers != [] and Enum.all?(tracks_buffers, fn {_key, value} -> value != [] end) do
      frames_with_lowest_timestamps =
        Enum.map(tracks_buffers, fn {key, ordered_frames_list} ->
          {key, List.last(ordered_frames_list)}
        end)

      {key, frame_buffer} =
        Enum.min_by(frames_with_lowest_timestamps, fn {_key, frame_buffer} -> frame_buffer.pts end)

      frames_buffer = Map.get(state.tracks_buffers, key)
      {_, frames_buffer} = List.pop_at(frames_buffer, length(frames_buffer) - 1)

      state = Map.put(state, :tracks_buffers, Map.put(state.tracks_buffers, key, frames_buffer))

      state =
        if Map.get(state.tracks_statuses, key) == :stream_ended and frames_buffer == [] do
          Map.put(state, :tracks_statuses, Map.put(state.tracks_statuses, key, :processed))
        else
          state
        end

      actions = [buffer: {:output, frame_buffer}]

      actions =
        if Enum.all?(state.tracks_statuses, fn {_key, value} -> value == :processed end) do
          actions ++ [end_of_stream: :output]
        else
          actions
        end

      {{:ok, nested_actions}, state} = prepare_buffers(state)
      {{:ok, actions ++ nested_actions}, state}
    else
      actions =
        tracks_buffers
        |> Enum.filter(fn {_key, value} -> value == [] end)
        |> Enum.map(fn {key, _value} -> {:demand, {Pad.ref(key), 1}} end)

      {{:ok, actions}, state}
    end
  end
end
