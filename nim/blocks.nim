import std/random
import std/segfaults
import wNim/wApp
import frames, rects
import concurrent, anneal



when isMainModule:
  try:
    randomize()
    concurrent.init()
    anneal.init()
    let init_size = (800, 600)
    var rectTable = RectTable()
    let app = App()
    discard MainFrame(init_size, rectTable)
    app.mainLoop()
    concurrent.deinit()
    anneal.deinit()
  except Exception as e:
    echo "Exception!!"
    echo e.msg
  