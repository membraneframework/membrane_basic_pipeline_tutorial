defmodule Basic.Elements.Mixer do
  @moduledoc """
  Element responsible for ordering the frames coming from two sources, basing on their timestamps.
  """
  use Membrane.Filter

  def_input_pad(:first_input, demand_unit: :buffers, caps: {Basic.Formats.Frame, encoding: :utf8})

  def_input_pad(:second_input, demand_unit: :buffers, caps: {Basic.Formats.Frame, encoding: :utf8})

  def_output_pad(:output, caps: {Basic.Formats.Frame, encoding: :utf8})

  defmodule Track do
    defstruct [:track_id, status: :ready, samples: []]
  end

  @impl true
  def handle_init(_options) do
    {:ok,
     %{
       tracks: [%Track{track_id: :first_input}, %Track{track_id: :second_input}]
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
    {track, rest} = pop_track(state.tracks, pad)

    tracks =
      if track.samples != [] do
        track = %Track{track | status: :end_of_stream}
        [track | rest]
      else
        rest
      end

    state = %{state | tracks: tracks}
    {state, actions} = update_state_and_prepare_actions(state)
    {{:ok, actions}, state}
  end

  @impl true
  def handle_process(pad, buffer, _context, state) do
    {track, rest_of_tracks} = pop_track(state.tracks, pad)
    track = %Track{track | samples: [buffer | track.samples]}
    tracks = [track | rest_of_tracks]
    state = %{state | tracks: tracks}
    {state, actions} = update_state_and_prepare_actions(state)
    # Demand on tracks where the samples list is empty
    actions =
      actions ++
        (tracks
         |> Enum.filter(fn track -> track.status == :ready and track.samples == [] end)
         |> Enum.map(fn track -> {:demand, {Pad.ref(track.track_id), 1}} end))

    {{:ok, actions}, state}
  end

  defp update_state_and_prepare_actions(state) do
    {buffers, tracks} = prepare_buffers(state.tracks)
    state = %{state | tracks: tracks}
    actions = Enum.map(buffers, fn buffer -> {:buffer, {:output, buffer}} end)
    # Send end_of_stream if all buffers are processed
    actions =
      if tracks == [] do
        actions ++ [end_of_stream: :output]
      else
        actions
      end

    {state, actions}
  end

  defp prepare_buffers(tracks) do
    if tracks != [] and Enum.all?(tracks, fn track -> track.samples != [] end) do
      {track_id, _pts} =
        tracks
        |> Enum.map(&{&1.track_id, List.last(&1.samples).pts})
        |> Enum.min_by(fn {_track_id, pts} -> pts end)

      {track, tracks} = pop_track(tracks, track_id)
      {buffer_to_output, rest} = List.pop_at(track.samples, length(track.samples) - 1)
      track = %{track | samples: rest}

      tracks =
        if track.samples != [] or track.status != :end_of_stream do
          [track | tracks]
        else
          tracks
        end

      {buffers, tracks} = prepare_buffers(tracks)
      {[buffer_to_output | buffers], tracks}
    else
      {[], tracks}
    end
  end

  defp pop_track(tracks, track_id) do
    index = tracks |> Enum.find_index(fn %Track{track_id: id} -> id == track_id end)
    List.pop_at(tracks, index)
  end
end
