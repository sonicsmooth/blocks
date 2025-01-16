import wNim/[wApp, wWindow]
import winim
import std/[random]
import frames, rects


  

when isMainModule:
  randomize()
  let init_size = (800, 600)
  var rectTable = RectTable()
  let app = App()
  var mainFrame = MainFrame(init_size, rectTable)
  app.mainLoop()