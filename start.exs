{:ok, pid} = Basic.Pipeline.start_link()
Basic.Pipeline.play(pid)
Process.sleep(2000)
