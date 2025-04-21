import std/random
import std/segfaults
import wNim/wApp
import wNim/wUtils
import mainframe, sdlframes, rectTable, db
import concurrent, anneal


when compileOption("profiler"):
  echo "profiling"
  import std/nimprof

when isMainModule:
  try:
    randomize()
    wSetSystemDpiAware()
    echo "DPI: ", wAppGetDpi()
    
    # Start stuff
    concurrent.init()
    anneal.init()
    sdlframes.initSDL()
    db.initDb()
    
    # Main data and window
    let init_size = (800, 800)
    var rectTable = RectTable()
    discard MainFrame(init_size)
    
    # Go App!
    let app = App()
    app.mainLoop()

    # Shut down
    concurrent.deinit()
    anneal.deinit()
    
  except Exception as e:
    echo "Exception!!"
    echo e.msg
    echo getStackTrace(e)
  