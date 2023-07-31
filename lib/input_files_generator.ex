defmodule InputFilesGenerator do
  @moduledoc """
  A module responsible for spliting a text file into multiple files, one per each speaker. Each of the files contains the packetized part of the text. A packet holds some part of the frame (a few characters from the line).
  The input consists of lines in the following form:
  ```
  <Speaker ID>: <text>
  ```

  In each of the output files there are packets in the following form:
  ```
  [seq:<sequence_id>][frameid:<frame_id>][timestamp:<timestamp>]<text>
  ```
  where:
  + sequence_id - the ordering number of the packet (relative to each of the peers). Basing on this number we will be able to assemble the particular frame.
  + frame_id - the identifier which consists of the number of the frame to which the body of a given packet belongs, optionally followed by a single character **'s'** (meaning that this packet is a **s**tarting packet of a frame) or by **'e'** character (meaning that the packet is the **e**nding packet of the frame). Note that frames are numbered relatively to each peer in that conversation and that frame_id does not describe the global order of the frames in the final file.
  + timestamp - a number indicating a time at which a given sentence was said. Timestamp describes the order of the frames from both peers.
  + text - the proper body of the packet, in our case - a bunch of characters which could be sent in a single packet.
  """
  def generate(input_location, how_many_packets_per_frame) do
    raw_file_binary = File.read!(input_location)
    content = String.split(raw_file_binary, "\n")
    content = fetch_information_about_peer(content)

    content =
      content
      |> Enum.with_index(1)
      |> Enum.map(fn {{speaker_name, line}, timestamp} ->
        {speaker_name,
         get_substrings_list(line, ceil(String.length(line) / how_many_packets_per_frame)),
         timestamp}
      end)

    unique_speakers =
      Enum.uniq(content |> Enum.map(fn {speaker, _content, _timestamp} -> speaker end))

    {format, output_path} = extract_format(input_location)

    for speaker <- unique_speakers do
      to_write =
        content
        |> Enum.filter(fn {speaker_name, _speaker_content, _timestamp} ->
          speaker_name == speaker
        end)
        |> Enum.with_index(1)
        |> Enum.map(fn {{_speaker_name, speaker_content, timestamp}, frame_id} ->
          prepare_sequence(speaker_content, frame_id, timestamp)
        end)
        |> Enum.flat_map(& &1)
        |> Enum.with_index(1)
        |> Enum.map(fn {packet, seq_id} -> "[seq:#{seq_id}]#{packet}" end)
        |> Enum.shuffle()
        |> Enum.join("\n")

      File.write!(output_path <> "." <> speaker <> "." <> format, to_write)
    end
  end

  defp prepare_sequence(content, frame_id, timestamp) do
    for {part, no} <- Enum.with_index(content, 1) do
      type = if no == length(content), do: "e", else: ""
      "[frameid:#{frame_id}#{type}][timestamp:#{timestamp}]#{part}"
    end
  end

  defp get_substrings_list(string, desired_length) when desired_length > 0 do
    {head, rest} = string |> String.split_at(desired_length)

    if String.length(rest) > 0,
      do: [head | get_substrings_list(rest, desired_length)],
      else: [head]
  end

  defp extract_format(string) do
    [format | rest] = Enum.reverse(String.split(string, "."))
    {format, Enum.join(rest, ".")}
  end

  defp fetch_information_about_peer(content) do
    content
    |> Enum.map(fn line ->
      [speaker_name | rest] = String.split(line, ": ")
      line = Enum.join(rest)
      {speaker_name, line}
    end)
  end
end
