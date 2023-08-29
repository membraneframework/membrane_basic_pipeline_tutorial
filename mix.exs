defmodule Basic.MixProject do
  use Mix.Project

  def project do
    [
      app: :basic,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:membrane_core, "~> 0.12.0"},
      {:membrane_core, path: "../membrane_core", override: true},
      {:membrane_raw_video_format, "~> 0.3.0"},
      {:membrane_raw_audio_format, "~> 0.11.0"},
      {:mock, "~> 0.3.0", only: :test}
    ]
  end
end
