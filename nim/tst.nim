
# var myseq = @[1,2,3]
# var refseq = cast[ref seq[int]](myseq.addr)
# var ptrseq = myseq.addr
# myseq.add(4)
# echo myseq
# echo refseq[]
# echo ptrseq[]
# echo cast[int](myseq.addr)
# echo cast[int](refseq)
# echo cast[int](ptrseq)

import std/[random, locks, sequtils]
from std/os import sleep
import wnim, winim

type 
  wBlockPanel = ref object of wPanel
  wMainPanel = ref object of wPanel
    mBlockPanel: wBlockPanel
    mButtons: array[1, wButton]
  wMainFrame = ref object of wFrame
    mMainPanel: wMainPanel
  Rect = tuple[rect: wRect, color: wColor]
  RSeq = seq[Rect]
  ThreadArg = tuple[pRects: ptr RSeq, sz: wSize, window: wMainPanel]

var 
  L: Lock
  gSendChan: Channel[bool]
  gAckChan: Channel[bool]
  myThread: Thread[ThreadArg]
  gRects: RSeq

initLock(L)
gSendChan.open()
gAckChan.open()

proc randColor: wColor = 
  let 
    b: int = rand(255) shl 16
    g: int = rand(255) shl 8
    r: int = rand(255)
  wColor(b or g or r) # 00bbggrr

proc randomizeRectsAll(pRects: ptr RSeq, sz: wSize, qty: int) {.gcsafe.} = 
  # Clear then fill the rect sequence
  pRects[].setLen(0)
  for i in 1..qty:
    let newRect: wRect = (rand(sz.width), rand(sz.height), rand(20..100), rand(20..100))
    let newColor: wColor = randColor()
    let newItem = (newRect, newColor)
    pRects[].add(newItem)


proc worker(arg: ThreadArg) {.thread.} =
  let pRects = arg.pRects
  let sz     = arg.sz
  let window = arg.window
  for i in 1..1000:
    withLock(L):
      randomizeRectsAll(pRects, sz, 100)
    window.refresh()
    gSendChan.send(true)
    discard gAckChan.recv()
    #sleep(1000)


wClass(wBlockPanel of wPanel):
  proc onPaint(self: wBlockPanel, event: wEvent) = 
    var dc = PaintDC(event.window)
    #dc.clear()
    withLock(L):
      for r in gRects:
        dc.setBrush(Brush(r.color))
        dc.drawRectangle(r.rect)
    let (avail, msg) = gSendChan.tryRecv()
    if avail > 0:
      gAckChan.send(true)

  proc init(self: wBlockPanel, parent: wWindow) = 
    wPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
    self.wEvent_Paint do (event: wEvent): self.onPaint(event)

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

  proc onResize(self: wMainPanel) =
    randomizeRectsAll(gRects.addr, self.mBlockPanel.clientSize, 10)
    self.Layout()
      
  proc onButtonTest(self: wMainPanel) =
    let sz = self.mBlockPanel.cLientSize
    createThread(myThread, worker, (gRects.addr, sz, self))
    # while myThread.running() or gRChan.peek() > 0:
    #   gRects = gRChan.recv()
    #   self.forceRedraw(0)
    # joinThread(myThread)

  proc init(self: wMainPanel, parent: wWindow) =
    wPanel(self).init(parent)
    self.mButtons[ 0] = Button(self, label = "Start long thing"     )
    self.mBlockPanel = BlockPanel(self)
    self.wEvent_Size                    do (event: wEvent): self.onResize()
    self.mButtons[ 0].wEvent_Button     do (): self.onButtonTest()




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
    randomizeRectsAll(gRects.addr, newBlockSz, 10)

    # Show!
    self.center()
    self.show()



when isMainModule:
  randomize()
  let init_size = (800, 600)
  let app = App()
  discard MainFrame(init_size)
  app.mainLoop()

gSendChan.close()
gAckChan.close()
deinitLock(L)
