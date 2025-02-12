import wNim, winim
import std/[random]
from std/os import sleep

import std/locks

var
  thr: array[0..4, Thread[tuple[a,b: int]]]
  L: Lock

# proc threadFunc(interval: tuple[a,b: int]) {.thread.} =
#   for i in interval.a..interval.b:
#     acquire(L) # lock stdout
#     echo i
#     release(L)

initLock(L)

# for i in 0..high(thr):
#   createThread(thr[i], threadFunc, (i*10, i*10+5))
# joinThreads(thr)

#deinitLock(L)


var gRects {.threadvar.}: seq[tuple[rect: wRect, color: wColor]]

proc randColor: wColor = 
  let 
    b: int = rand(255) shl 16
    g: int = rand(255) shl 8
    r: int = rand(255)
  wColor(b or g or r) # 00bbggrr


wClass(wBlockPanel of wPanel):
  proc onPaint(self: wBlockPanel, event: wEvent) = 
    # Finally grab DC and do last blit
    var dc = PaintDC(event.window)
    for r in gRects:
      dc.setBrush(Brush(r.color))
      dc.drawRectangle(r.rect)


  proc init(self: wBlockPanel, parent: wWindow) = 
    wPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
    self.wEvent_Paint      do (event: wEvent): self.onPaint(event)



type wMainPanel = ref object of wPanel
  mBlockPanel: wBlockPanel
  mButtons: array[1, wButton]

var thr2: array[0..1, Thread[tuple[self: wMainPanel, sz: wSize]]]

wClass(wMainPanel of wPanel):
  proc Layout(self: wMainPanel) =
    let 
      (cszw, cszh) = self.clientSize
      bmarg = 8
      (bw, bh) = (130, 30)
      (lbpmarg, rbpmarg, tbpmarg, bbpmarg) = (0, 8, 0, 0)
    self.mBlockPanel.position = (bw + 2*bmarg + lbpmarg, tbpmarg)
    self.mBlockPanel.size = (cszw - bw - 2*bmarg - lbpmarg - rbpmarg, 
                             cszh - tbpmarg - bbpmarg)
    var yPosAcc = 0
    # Buttons position, size
    for i, butt in self.mButtons:
      butt.position = (bmarg, yPosAcc)
      butt.size     = (bw, bh)
      yPosAcc += bh

  proc forceRedraw(self: wMainPanel, wait: int) = 
    self.refresh(false)
    UpdateWindow(self.mBlockPanel.mHwnd)
    sleep(wait)


  proc randomizeRectsAll(self: wMainPanel, qty: int, sz: wSize) = 
    gRects.setLen(0)
    for i in 1..qty:
      let r: wRect = (rand(sz.width),
                      rand(sz.height),
                      rand(20..100),
                      rand(20..100))
      let c: wColor = randcolor()
      gRects.add((r,c))

  proc onResize(self: wMainPanel) =
    echo "Size of gRects: ", gRects.len
    self.randomizeRectsAll(10, self.mBlockPanel.clientSize)
    self.Layout()
      
  proc worker(arg: tuple[self: wMainPanel, sz: wSize]) {.thread.} =
    for i in 1..100:
      echo i
      acquire(L)
      arg.self.randomizeRectsAll(100, arg.sz)
      echo "Size of gRects: ", gRects.len
      release(L)
      #arg.self.forceRedraw(100)

  proc onButtonTest(self: wMainPanel) =
    let arg = (self, self.mBlockPanel.cLientSize)
    createThread(thr2[0], worker, arg)
    joinThread(thr2[0])
    self.refresh()

  proc init(self: wMainPanel, parent: wWindow) =
    wPanel(self).init(parent)

    # Create controls
    self.mButtons[ 0] = Button(self, label = "Start long thing"     )

    # Set up stuff
    self.mBlockPanel = BlockPanel(self)

    # Connect events
    self.wEvent_Size                    do (event: wEvent): self.onResize()
    self.mButtons[ 0].wEvent_Button     do (): self.onButtonTest()



type wMainFrame = ref object of wFrame
  mMainPanel: wMainPanel
wClass(wMainFrame of wFrame):
  proc onResize(self: wMainFrame, event: wEvent) =
    self.mMainPanel.size = (event.size.width, event.size.height - self.mStatusBar.size.height)

  proc init*(self: wMainFrame, newBlockSz: wSize) = 
    wFrame(self).init(title="Blocks Frame")
    
    # Create controls
    self.mMainPanel   = MainPanel(self)

    let
      otherWidth  = self.size.width  - self.mMainPanel.mBlockPanel.clientSize.width
      otherHeight = self.size.height - self.mMainPanel.mBlockPanel.clientSize.height
      newWidth    = newBlockSz.width  + otherWidth
      newHeight   = newBlockSz.height + otherHeight + 23

    # Do stuff
    self.size = (newWidth, newHeight)
    self.mMainPanel.randomizeRectsAll(10, newBlockSz)

    # Show!
    self.center()
    self.show()





  

when isMainModule:
  randomize()
  let init_size = (800, 600)
  let app = App()
  discard MainFrame(init_size)
  app.mainLoop()
  