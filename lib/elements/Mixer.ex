defmodule Basic.Elements.Mixer do
  @moduledoc """
  Element responsible for mixing the frames coming from two sources, basing on their timestamps.
  """
  use Membrane.Filter

  def_input_pad(:first_input, demand_unit: :buffers, caps: {Basic.Formats.Frame, encoding: :utf8})

  def_input_pad(:second_input, demand_unit: :buffers, caps: {Basic.Formats.Frame, encoding: :utf8})

  def_output_pad(:output, caps: {Basic.Formats.Frame, encoding: :utf8})

  defmodule Track do
    @type status_t :: :playing | :no_more_buffers | :end_of_stream
    @type t :: %__MODULE__{
            status: status_t(),
            samples: [Membrane.Buffer.t()]
          }

    defstruct status: :playing, samples: []
  end

  @impl true
  def handle_init(_options) do
    {:ok,
     %{
       tracks: %{first_input: %Track{}, second_input: %Track{}}
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
    tracks = Map.put(state.tracks, pad, %Track{Map.get(state.tracks, pad)| status: :no_more_buffer})
    tracks = update_tracks_status(tracks, pad)
    state = %{state | tracks: tracks}
    {state, actions} = update_state_and_prepare_actions(state)
    {{:ok, actions}, state}
  end

  @impl true
  def handle_process(pad, buffer, _context, state) do
    tracks =
      Map.update!(state.tracks, pad, fn track ->
        %Track{track | samples: [buffer | track.samples]}
      end)
    state = %{state | tracks: tracks}
    {state, actions} = update_state_and_prepare_actions(state)
    # Demand on tracks where the samples list is empty
    actions =
      actions ++
        (tracks
         |> Enum.filter(fn {_, track} -> track.status == :playing and track.samples == [] end)
         |> Enum.map(fn {track_id, _} -> {:demand, {Pad.ref(track_id), 1}} end))

    {{:ok, actions}, state}
  end

  defp update_state_and_prepare_actions(state) do
    {buffers, tracks} = prepare_buffers(state.tracks)
    state = %{state | tracks: tracks}
    actions = Enum.map(buffers, fn buffer -> {:buffer, {:output, buffer}} end)
    # Send end_of_stream if all buffers are processed
    actions =
      if Enum.all?(state.tracks, fn {_, track} -> track.status == :end_of_stream end) do
        actions ++ [end_of_stream: :output]
      else
        actions
      end
    {state, actions}
  end

  defp prepare_buffers(tracks) do
    IO.puts("TRACKS: #{inspect(tracks)}")
    active_tracks =
      tracks |> Enum.reject(fn {_track_id, track}-> track.status==:end_of_stream end) |> Map.new()
    if active_tracks != %{} and
         Enum.all?(active_tracks, fn {_, track} -> track.samples != [] end) do
      {track_id, _track} =
        active_tracks
        |> Enum.min_by(fn {_track_id, track} -> List.last(track.samples).pts end)
      track = Map.get(tracks, track_id)
      {buffer_to_output, rest} = List.pop_at(track.samples, length(track.samples) - 1)
      tracks = Map.put(tracks, track_id, %Track{track| samples: rest})
      tracks = update_tracks_status(tracks, track_id)
      {buffers, tracks} = prepare_buffers(tracks)
      {[buffer_to_output | buffers], tracks}
    else
      {[], tracks}
    end
  end

  defp update_tracks_status(tracks, track_id) do
    Map.update!(tracks, track_id, fn track ->
      if track.status == :no_more_buffers and track.samples == [] do
        %Track{status: :end_of_stream}
      else
        track
      end
    end)
  end

end
