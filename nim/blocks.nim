import wNim/[wApp]
import std/[random, tables]
import frames, rects


  

when isMainModule:
  randomize()
  let init_size = (800, 600)
  var rectTable: ref RectTable
  new rectTable
  let app = App()
  discard MainFrame(init_size, rectTable)
  app.mainLoop()