import std/random
import std/segfaults
import wNim/wApp
import wNim/wUtils
import frames, sdlframes, rectTable
import concurrent, anneal

var
  userdata: pointer

proc EventFilter(userdata: pointer, event: ptr Event): Bool32 {.cdecl.} =
  echo event.kind
  #return False32
  return True32

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
    #setEventFilter(EventFilter, userdata)
    
    # Main data and window
    let init_size = (800, 800)
    var rectTable = RectTable()
    discard MainFrame(init_size, rectTable)
    
    # Go App!
    let app = App()
    app.mainLoop()

    # Shut down
    concurrent.deinit()
    anneal.deinit()
    
  except Exception as e:
    echo "Exception!!"
    echo e.msg
  