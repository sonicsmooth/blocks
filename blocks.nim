import wNim/[wApp]
import std/[random]
import frames, rects


  

var rt: RectTable

when isMainModule:
  randomize()
  let rectTable = InitRects(800, 600)

  let app = App()
  let mf = MainFrame(rectTable)
  #mf.setRects()

  app.mainLoop()