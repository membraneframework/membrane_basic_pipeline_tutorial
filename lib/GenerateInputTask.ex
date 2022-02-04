defmodule Mix.Tasks.GenerateInput do
  @moduledoc "The generate_input mix task: `mix help generate_input`"
  use Mix.Task
  @default_packets_per_frame 5

  @shortdoc "Calls InputFilesGenerator/2"
  def run(args) do
    {options, arguments, errors} = OptionParser.parse(args, strict: [packetsPerFrame: :integer])

    packets_per_frame = Keyword.get(options, :packetsPerFrame, @default_packets_per_frame)
    if length(errors) != 0 or length(arguments) != 1 do
      inform_about_an_error()
    else
      [input_file_path] = arguments
      InputFilesGenerator.generate(input_file_path, packets_per_frame)
      IO.puts("Files generated successfully")
    end

  end


  defp inform_about_an_error do
    IO.puts("Improper usage. Try: mix generate_input --packetsPerFrame <packets per frame> <input file>")
  end
end
