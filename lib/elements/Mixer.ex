defmodule Basic.Elements.Mixer do
  @moduledoc """
  Element responsible for mixing the frames coming from two sources, basing on their timestamps.
  """
  use Membrane.Filter

  def_input_pad(:input, demand_unit: :buffers, availability: :on_request, caps: {Basic.Formats.Frame, encoding: :utf8})

  def_output_pad(:output, caps: {Basic.Formats.Frame, encoding: :utf8})

  defmodule Track do
    @type t :: %__MODULE__{
            buffer: Membrane.Buffer.t(),
            status: :started | :finished
          }

    defstruct buffer: nil, status: :started
  end

  @impl true
  def handle_init(_options) do
    {:ok,
     %{
       tracks: %{}
     }}
  end

  @impl true
  def handle_demand(:output, size, _unit, ctx, state) when size > 0 do
    {state, actions} = update_state_and_prepare_actions(state, ctx.pads)
    {{:ok, actions}, state}
  end

  @impl true
  def handle_demand(_ref, _size, _unit, _ctx, state), do: {state, []}

  @impl true
  def handle_pad_added(pad, _context, state) do
    state = %{state| tracks: Map.put(state.tracks, pad, %Track{})}
    {:ok, state}
  end

  @impl true
  def handle_end_of_stream(pad, _context, state) do
    tracks =
      Map.update!(state.tracks, pad, fn track ->
        %Track{track | status: :finished}
      end)

    state = %{state | tracks: tracks}
    {{:ok, [{:redemand, :output}]}, state}
  end

  @impl true
  def handle_process(pad, buffer, _context, state) do
    tracks =
      Map.update!(state.tracks, pad, fn track ->
        %Track{track | buffer: buffer}
      end)

    state = %{state | tracks: tracks}
    {{:ok, [{:redemand, :output}]}, state}
  end

  defp update_state_and_prepare_actions(state, pads) do
    {state, buffer_actions} = output_buffers(state)
    {state, end_of_stream_actions} = send_end_of_stream(state)
    {state, demand_actions} = demand_on_empty_tracks(state, pads)

    actions = buffer_actions ++ end_of_stream_actions ++ demand_actions
    {state, actions}
  end

  defp output_buffers(state) do
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

    if active_tracks != %{} and
         Enum.all?(active_tracks, fn {_, track} -> track.buffer != nil end) do
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

  defp send_end_of_stream(state) do
    end_of_stream_actions =
      if Enum.all?(state.tracks, fn {_, track} -> track.status == :finished end) do
        [end_of_stream: :output]
      else
        []
      end

    {state, end_of_stream_actions}
  end

  defp demand_on_empty_tracks(state, pads) do
    actions =
      state.tracks
      |> Enum.filter(fn {track_id, track} ->
        track.status != :finished and track.buffer == nil and pads[track_id].demand == 0
      end)
      |> Enum.map(fn {track_id, _} -> {:demand, {Pad.ref(track_id), 1}} end)

    {state, actions}
  end
end
