defmodule InputFilesGenerator do
  @moduledoc """
  A module responsible for spliting a text file into two files, each of which contains the packetized part of the text. An packet holds a single word.
  The packets are in the following form:
  ```
  [seq:<sequence_id>][frameid:<frame_id>][timestamp:<timestamp>]<text>
  ```
  where:
  + sequence_id - the ordering number of the packet (relative to each of the peers). Basing on this number we will be able to assemble the particular frame.
  + frame_id - the identifier which consists of the number of the frame to which the body of a given packet belongs, optionally followed by a single character **'s'** (meaning that this packet is a **s**tarting packet of a frame) or by **'e'** character (meaning that the packet is the **e**nding packet of the frame). Note that frames are numbered relatively to each peer in that conversation and that frame_id does not describe the global order of the frames in the final file.
  + timestamp - a number indicating where the given frame should be put in the final file.
  + text - the proper body of the packet, in our case - a single word.

  The first file contains odd lines from the input file and the second file contians the even ones.
  """
  def generate(input_location, output_name, how_many_packets_per_frame) do
    raw_file_binary = File.read!(input_location)
    content = String.split(raw_file_binary, "\n")

    content =
      Enum.map(
        content,
        &get_substrings_list(&1, ceil(String.length(&1) / how_many_packets_per_frame))
      )

    content = Enum.zip(content, Range.new(1, length(content)))
    first_speaker_content = Enum.filter(content, fn {_words_list, no} -> rem(no, 2) != 0 end)
    second_speaker_content = Enum.filter(content, fn {_words_list, no} -> rem(no, 2) == 0 end)
    first_speaker_content = prepare_sequence(first_speaker_content)
    second_speaker_content = prepare_sequence(second_speaker_content)
    File.write!(output_name <> "1.txt", first_speaker_content)
    File.write!(output_name <> "2.txt", second_speaker_content)
  end

  defp prepare_sequence(content) do
    content =
      for {{words_list, timestamp}, frame_id} <- Enum.with_index(content, 1) do
        for {word, no} <- Enum.with_index(words_list, 1) do
          type = if no == length(words_list), do: "e", else: ""
          "[frameid:#{frame_id}#{type}][timestamp:#{timestamp}]#{word}"
        end
      end

    content = Enum.flat_map(content, & &1)

    content =
      content
      |> Enum.with_index(1)
      |> Enum.map(fn {sequence, sequence_id} -> "[seq:#{sequence_id}]#{sequence}" end)

    Enum.shuffle(content) |> Enum.join("\n")
  end

  defp get_substrings_list(string, desired_length) when desired_length > 0 do
    {head, rest} = string |> String.split_at(desired_length)

    if String.length(rest) > 0,
      do: [head | get_substrings_list(rest, desired_length)],
      else: [head]
  end
end
