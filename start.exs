{:ok, _sup, pipeline} = Membrane.Pipeline.start_link(Basic.Pipeline)
Process.monitor(pipeline)

# Wait for the pipeline to terminate
receive do
  {:DOWN, _monitor, :process, ^pipeline, _reason} -> :ok
end
