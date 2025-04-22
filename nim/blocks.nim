import std/random
import wNim/[wApp, wWindow, wUtils]
import mainframe, sdlframes, db
import concurrent, anneal


when compileOption("profiler"):
  echo "profiling"
  import std/nimprof

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
  let app = App()
  let init_size = (800, 800)
  let frame = MainFrame(init_size)
  
  # Go App!
  frame.center()
  frame.show()

  app.mainLoop()

  # Shut down
  concurrent.deinit()
  anneal.deinit()
    
except Exception as e:
  echo "Exception!!"
  echo e.msg
  echo getStackTrace(e)
  