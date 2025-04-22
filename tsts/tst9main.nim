import std/macros
import tst9
import wNim/[wApp, wWindow]

when isMainModule:
  let app = App(wSystemDpiAware)
  let sz: wSize = (640, 400)
  let frame = MainFrame(sz)

  frame.center()
  frame.show()
  app.mainLoop()