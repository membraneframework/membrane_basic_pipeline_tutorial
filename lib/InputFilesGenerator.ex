defmodule InputFilesGenerator do
  def generate(input_location, output_name) do
    raw_file_binary = File.read!(input_location)
    content = String.split(raw_file_binary, "\n")
    content = Enum.map(content, &String.split(&1, " "))
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

    content = Enum.sort(content, fn _x, _y -> Enum.random([false, true]) end)
    Enum.join(content, "\n")
  end
end
