defmodule Basic.Elements.Mixer do
  @moduledoc """
  Element responsible for mixing the frames coming from two sources, basing on their timestamps.
  """
  use Membrane.Filter

  def_input_pad(:first_input, demand_unit: :buffers, caps: {Basic.Formats.Frame, encoding: :utf8})

  def_input_pad(:second_input, demand_unit: :buffers, caps: {Basic.Formats.Frame, encoding: :utf8})

  def_output_pad(:output, caps: {Basic.Formats.Frame, encoding: :utf8})

  defmodule Track do
    @type status_t :: :started | :finished
    @type t :: %__MODULE__{
            buffer: Membrane.Buffer.t(),
            demanded: boolean(),
            status: status_t()
          }

    defstruct buffer: nil, demanded: false, status: :started
  end

  @impl true
  def handle_init(_options) do
    {:ok,
     %{
       tracks: %{first_input: %Track{}, second_input: %Track{}}
     }}
  end

  @impl true
  def handle_demand(_ref, size, _unit, _ctx, state) do
    {state, actions} =
      if size > 0 do
        update_state_and_prepare_actions(state)
      else
        {state, []}
      end

    {{:ok, actions}, state}
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
        %Track{track | buffer: buffer, demanded: false}
      end)

    state = %{state | tracks: tracks}
    {{:ok, [{:redemand, :output}]}, state}
  end

  defp update_state_and_prepare_actions(state) do
    {state, buffer_actions} = output_buffers(state)
    {state, end_of_stream_actions} = send_end_of_stream(state)
    {state, demand_actions} = demand_on_empty_tracks(state)

    actions = buffer_actions ++ end_of_stream_actions ++ demand_actions
    {state, actions}
  end

  defp output_buffers(state) do
    {buffers, tracks} = prepare_buffers(state.tracks)
    state = %{state | tracks: tracks}
    buffer_actions = Enum.map(buffers, fn buffer -> {:buffer, {:output, buffer}} end)
    {state, buffer_actions}
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

  defp demand_on_empty_tracks(state) do
    actions =
      state.tracks
      |> Enum.filter(fn {_, track} ->
        track.status == :started and track.buffer == nil and track.demanded == false
      end)
      |> Enum.map(fn {track_id, _} -> {:demand, {Pad.ref(track_id), 1}} end)

    tracks =
      state.tracks
      |> Enum.map(fn {track_id, track} ->
        if track.status == :started and track.buffer == nil and track.demanded == false do
          {track_id, %Track{track | demanded: true}}
        else
          {track_id, track}
        end
      end)
      |> Map.new()

    state = %{state | tracks: tracks}
    {state, actions}
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

      tracks = Map.put(tracks, track_id, %Track{track | buffer: nil, demanded: false})
      {buffers, tracks} = prepare_buffers(tracks)
      {[track.buffer | buffers], tracks}
    else
      {[], tracks}
    end
  end
end
