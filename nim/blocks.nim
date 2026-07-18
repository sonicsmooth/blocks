import std/[random]
import wNim/[wApp,wUtils]
import appopts, document
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

    # TODO: Move to application
    # Start stuff
    # concurrent.init()
    # anneal.init()
    
    # Main data and window
    var app: Application
    app.init(1200, 800)
    if not app.isReady():
      echo "Application not ready"
      system.quit()
    app.go()

    # ... wait for user to shut down ... #

    # Shut down
    #concurrent.deinit()
    #anneal.deinit()
      
  except Exception as e:
    echo "Exception!"
    echo e.msg
    echo getStackTrace(e)
  