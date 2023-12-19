defmodule Basic.Elements.Mixer do
  @moduledoc """
  Element responsible for mixing the frames coming from two sources, based on their timestamps.
  """
  use Membrane.Filter
  alias Basic.Formats.Frame

  def_input_pad :first_input,
    flow_control: :manual,
    demand_unit: :buffers,
    accepted_format: %Frame{encoding: :utf8}

  def_input_pad :second_input,
    flow_control: :manual,
    demand_unit: :buffers,
    accepted_format: %Frame{encoding: :utf8}

  def_output_pad :output,
    flow_control: :manual,
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
  def handle_buffer(pad, buffer, _context, state) do
    tracks = Map.update!(state.tracks, pad, &%Track{&1 | buffer: buffer})
    {tracks, buffer_actions} = get_output_buffers_actions(tracks)
    state = %{state | tracks: tracks}

    {buffer_actions ++ [redemand: :output], state}
  end

  @impl true
  def handle_end_of_stream(pad, _context, state) do
    tracks = Map.update!(state.tracks, pad, &%Track{&1 | status: :finished})
    {tracks, buffer_actions} = get_output_buffers_actions(tracks)
    state = %{state | tracks: tracks}

    if Enum.all?(tracks, fn {track_id, track} ->
         track.status == :finished and not has_buffer?({track_id, track})
       end) do
      {buffer_actions ++ [end_of_stream: :output], state}
    else
      {buffer_actions ++ [redemand: :output], state}
    end
  end

  @impl true
  def handle_demand(:output, _size, _unit, context, state) do
    demand_actions =
      state.tracks
      |> Enum.reject(&has_buffer?/1)
      |> Enum.filter(fn {track_id, track} ->
        track.status != :finished and context.pads[track_id].demand == 0
      end)
      |> Enum.map(fn {track_id, _track} -> {:demand, {track_id, 1}} end)

    {demand_actions, state}
  end

  defp has_buffer?({_track_id, track}),
    do: track.buffer != nil

  defp can_send_buffer?(tracks) do
    started_tracks =
      Enum.filter(
        tracks,
        fn {_track_id, track} -> track.status != :finished end
      )

    (started_tracks == [] and Enum.any?(tracks, &has_buffer?/1)) or
      (started_tracks != [] and Enum.all?(started_tracks, &has_buffer?/1))
  end

  defp get_output_buffers_actions(tracks) do
    {buffers, tracks} = prepare_buffers(tracks)
    buffer_actions = Enum.map(buffers, fn buffer -> {:buffer, {:output, buffer}} end)
    {tracks, buffer_actions}
  end

  defp prepare_buffers(tracks) do
    if can_send_buffer?(tracks) do
      {next_track_id, next_track} =
        tracks
        |> Enum.filter(&has_buffer?/1)
        |> Enum.min_by(fn {_track_id, track} -> track.buffer.pts end)

      tracks = Map.put(tracks, next_track_id, %Track{next_track | buffer: nil})
      {buffers, tracks} = prepare_buffers(tracks)
      {[next_track.buffer | buffers], tracks}
    else
      {[], tracks}
    end
  end
end
