import std/random
import std/segfaults
import wNim/wApp
import wNim/wUtils
import frames, rectTable
import concurrent, anneal

when compileOption("profiler"):
  echo "profiling"
  import std/nimprof

when isMainModule:
  try:
    randomize()
    wSetSystemDpiAware()
    echo "DPI: ", wAppGetDpi()
    concurrent.init()
    anneal.init()
    let init_size = (800, 1200)
    var rectTable = RectTable()
    let app = App()
    discard MainFrame(init_size, rectTable)
    discard SDLFrame(init_size)
    app.mainLoop()
    concurrent.deinit()
    anneal.deinit()
  except Exception as e:
    echo "Exception!!"
    echo e.msg
  