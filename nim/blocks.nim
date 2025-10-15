import std/[os, parseopt, paths, random, strutils, strformat]
import wNim/[wApp, wWindow, wUtils]
import appopts, mainframe, sdlframes, db
import concurrent, anneal

# TODO: buttons for above


when isMainModule:
  when compileOption("profiler"):
    echo "profiling"
    import std/nimprof
  try:
    gAppOpts = parseAppOptions()
    if gAppOpts.appHelp:
      showAppHelp(gAppOpts)
      system.quit()

    randomize()
    wSetSystemDpiAware()
    when defined(debug):
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
    echo "Exception!"
    echo e.msg
    echo getStackTrace(e)
  