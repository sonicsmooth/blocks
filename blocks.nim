import std/random
import wNim/wApp
import concurrent, frames, rects



when isMainModule:
  randomize()
  concurrent.init()
  let init_size = (800, 600)
  var rectTable = RectTable()
  let app = App()
  discard MainFrame(init_size, rectTable)
  app.mainLoop()
  concurrent.deinit()
  