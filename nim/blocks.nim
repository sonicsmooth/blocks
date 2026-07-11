import std/[os, parseopt, paths, random, strutils, strformat]
import wNim/[wApp, wWindow, wUtils]
import appopts, mainframe, sdlframes, document
import concurrent, anneal
import application


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
    # concurrent.init()
    # anneal.init()
    #sdlframes.initSDL()
    #document.initDb()
    
    # Main data and window
    var app: Application
    app.init(1200, 800)
    app.go()

    # ... wait for user to shut down ... #

    # Shut down
    #concurrent.deinit()
    #anneal.deinit()
      
  except Exception as e:
    echo "Exception!"
    echo e.msg
    echo getStackTrace(e)
  