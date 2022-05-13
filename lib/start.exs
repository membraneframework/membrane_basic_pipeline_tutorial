{:ok, pid} = Basic.Pipeline.start()
Basic.Pipeline.play(pid)
Process.sleep(500)
