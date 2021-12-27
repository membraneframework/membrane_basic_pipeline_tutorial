defmodule Basic.Elements.Decryptor do
  use Membrane.Filter

  def_input_pad :input, demand_unit: :buffers, caps: :any
  def_output_pad :output, caps: :any
  def_options x: [type: :integer, spec: pos_integer, description: "test"]
  @impl true
  def handle_demand(_ref, size, _unit, _ctx, state) do
    {{:ok, demand: {Pad.ref(:input), size}}, state}
  end

  @impl true
  def handle_process(_ref, %Membrane.Buffer{payload: payload}, _ctx, state) do

    decrypted_payload = for {n, payload_text} <- payload do
      decrypted_payload_text = payload_text |> String.split("[encrypted]") |> Enum.at(1)
      {n, decrypted_payload_text}
    end
    buffer = %Membrane.Buffer{payload: decrypted_payload}
    {{:ok, buffer: {:output, buffer}}, state}
  end
end
