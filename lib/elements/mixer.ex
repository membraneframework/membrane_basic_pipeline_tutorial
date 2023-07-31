defmodule Basic.Elements.Mixer do
  @moduledoc """
  Element responsible for mixing the frames coming from two sources, basing on their timestamps.
  """
  use Membrane.Filter
  alias Basic.Formats.Frame

  def_input_pad :first_input,
    demand_unit: :buffers,
    accepted_format: %Frame{encoding: :utf8}

  def_input_pad :second_input,
    demand_unit: :buffers,
    accepted_format: %Frame{encoding: :utf8}

  def_output_pad :output,
    accepted_format: %Frame{encoding: :utf8}

  defmodule Track do
    @type t :: %__MODULE__{
            buffer: Membrane.Buffer.t(),
            status: :started | :finished
          }
    defstruct buffer: nil, status: :started
  end

  @impl true
  def handle_init(_context, _options) do
    {[],
     %{
       tracks: %{first_input: %Track{}, second_input: %Track{}}
     }}
  end

  @impl true
  def handle_process(pad, buffer, _context, state) do
    new_tracks = Map.update!(state.tracks, pad, &%Track{&1 | buffer: buffer})
    new_state = %{state | tracks: new_tracks}
    {[redemand: :output], new_state}
  end

  @impl true
  def handle_end_of_stream(pad, _context, state) do
    new_tracks = Map.update!(state.tracks, pad, &%Track{&1 | status: :finished})
    new_state = %{state | tracks: new_tracks}
    {[redemand: :output], new_state}
  end

  @impl true
  def handle_demand(:output, _size, _unit, context, state) do
    {state, buffer_actions} = get_output_buffers_actions(state)
    {state, end_of_stream_actions} = maybe_send_end_of_stream(state)
    {state, demand_actions} = get_demand_actions(state, context.pads)

    actions = buffer_actions ++ end_of_stream_actions ++ demand_actions
    {actions, state}
  end

  defp get_output_buffers_actions(state) do
    {buffers, tracks} = prepare_buffers(state.tracks)
    state = %{state | tracks: tracks}
    buffer_actions = Enum.map(buffers, fn buffer -> {:buffer, {:output, buffer}} end)
    {state, buffer_actions}
  end

  defp prepare_buffers(tracks) do
    active_tracks =
      tracks
      |> Enum.reject(fn {_track_id, track} ->
        track.status == :finished and track.buffer == nil
      end)
      |> Map.new()

    if active_tracks != %{} and Enum.all?(active_tracks, fn {_, track} -> track.buffer != nil end) do
      {track_id, track} =
        active_tracks
        |> Enum.min_by(fn {_track_id, track} -> track.buffer.pts end)

      buffer = track.buffer
      tracks = Map.put(tracks, track_id, %Track{track | buffer: nil})
      {buffers, tracks} = prepare_buffers(tracks)
      {[buffer | buffers], tracks}
    else
      {[], tracks}
    end
  end

  defp maybe_send_end_of_stream(state) do
    end_of_stream_actions =
      if Enum.all?(state.tracks, fn {_, track} -> track.status == :finished end) do
        [end_of_stream: :output]
      else
        []
      end

    {state, end_of_stream_actions}
  end

  defp get_demand_actions(state, pads) do
    actions =
      state.tracks
      |> Enum.filter(fn {track_id, track} ->
        track.status != :finished and track.buffer == nil and pads[track_id].demand == 0
      end)
      |> Enum.map(fn {track_id, _} -> {:demand, {Pad.ref(track_id), 1}} end)

    {state, actions}
  end
end
