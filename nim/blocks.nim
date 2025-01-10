import wNim/[wApp]
import std/[random, tables]
import frames, rects


  

when isMainModule:
  randomize()
  let rectTable = InitRects(800, 600)
  let app = App()
  discard MainFrame(rectTable)
  app.mainLoop()