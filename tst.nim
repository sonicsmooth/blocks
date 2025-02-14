import std/[random, locks, sequtils]
from std/os import sleep

var glock: Lock
var gdata {.guard: glock.}: int = 5
var myint: int = 19
var pint: ptr = addr myint
var myseq: seq[int] = @[0,4,6]
var pseq: ptr = myseq.addr

initLock(glock)

echo GC_getStatistics()

#{.locks: [glock].}:
proc worker1(s: ptr) {.thread.} =
  for i in 1..1000000:
    withLock(glock):
      s[0] += 1

proc worker2(s: ptr) {.thread.} =
  for i in 1..1000000:
    withLock(glock):
      pseq[0] -= 1

var mythr1: Thread[ptr seq[int]]
var mythr2: Thread[ptr seq[int]]

echo myseq
mythr1.createThread(worker1, pseq)
mythr2.createThread(worker2, pseq)
mythr1.joinThread()
mythr2.joinThread()
echo myseq

deinitLock(glock)



# #const maxCnt = 100000
# var L: Lock
# var sharedCounter: int
# type 
#   wBlockPanel = ref object of wPanel
#   wMainPanel = ref object of wPanel
#     mBlockPanel: wBlockPanel
#     mButtons: array[1, wButton]
#   wMainFrame = ref object of wFrame
#     mMainPanel: wMainPanel
#   Rect = tuple[rect: wRect, color: wColor]
#   RSeq = seq[Rect]
#   ISeq = seq[int]
#   ThreadArg = tuple[sz:wSize, window: wMainPanel]

# var 
#   gRects: RSeq
#   gRChan: Channel[RSeq]
#   t3: Thread[ThreadArg]

# gRChan.open()
# initLock(L)

# proc randColor: wColor = 
#   let 
#     b: int = rand(255) shl 16
#     g: int = rand(255) shl 8
#     r: int = rand(255)
#   wColor(b or g or r) # 00bbggrr

# proc randomizeRectsAll(sz: wSize, qty: int): RSeq {.gcsafe.} = 
#   for i in 1..qty:
#     let r: wRect = (rand(sz.width),
#                     rand(sz.height),
#                     rand(20..100),
#                     rand(20..100))
#     let c: wColor = randcolor()
#     result.add((r,c))


# proc worker(arg: ThreadArg) {.thread.} =
#   for i in 1..5:
#     gRChan.send(randomizeRectsAll(arg.sz, 100))
#     arg.window.refresh()
#     withLock(L):
#       echo "sent"
#     sleep(1000)
#   echo "Worker done"



# wClass(wBlockPanel of wPanel):
#   proc onPaint(self: wBlockPanel, event: wEvent) = 
#     var dc = PaintDC(event.window)
#     if gRChan.peek() > 0:
#       while true:
#         dc.clear()
#         let (b, msg) = gRChan.tryRecv()
#         if b:
#           echo "available:", msg.len
#           gRects = msg
#           for r in gRects:
#             dc.setBrush(Brush(r.color))
#             dc.drawRectangle(r.rect)
#         else:
#           echo "not available"
#           break
#     else:
#         for r in gRects:
#           dc.setBrush(Brush(r.color))
#           dc.drawRectangle(r.rect)


#   proc init(self: wBlockPanel, parent: wWindow) = 
#     wPanel(self).init(parent, style=wBorderSimple)
#     self.backgroundColor = wLightBlue
#     self.wEvent_Paint do (event: wEvent): self.onPaint(event)






# wClass(wMainPanel of wPanel):
#   proc Layout(self: wMainPanel) =
#     let 
#       (cszw, cszh) = self.clientSize
#       bmarg = 8
#       (bw, bh) = (130, 30)
#       (lbpmarg, rbpmarg, tbpmarg, bbpmarg) = (0, 8, 0, 0)
#     self.mBlockPanel.position = (bw + 2*bmarg + lbpmarg, tbpmarg)
#     self.mBlockPanel.size = (cszw - bw - 2*bmarg - lbpmarg - rbpmarg, 
#                              cszh - tbpmarg - bbpmarg)
#     var yPosAcc = 0
#     # Buttons position, size
#     for i, butt in self.mButtons:
#       butt.position = (bmarg, yPosAcc)
#       butt.size     = (bw, bh)
#       yPosAcc += bh

#   proc forceRedraw(self: wMainPanel, wait: int) = 
#     self.refresh(false)
#     UpdateWindow(self.mBlockPanel.mHwnd)
#     sleep(wait)

#   proc onResize(self: wMainPanel) =
#     gRects = randomizeRectsAll(self.mBlockPanel.clientSize, 10)
#     self.Layout()
      
#   proc onButtonTest(self: wMainPanel) =
#     let sz = self.mBlockPanel.cLientSize
#     createThread(t3, worker, (sz, self))
#     # while t3.running() or gRChan.peek() > 0:
#     #   gRects = gRChan.recv()
#     #   self.forceRedraw(0)
#     # joinThread(t3)

#   proc init(self: wMainPanel, parent: wWindow) =
#     wPanel(self).init(parent)
#     self.mButtons[ 0] = Button(self, label = "Start long thing"     )
#     self.mBlockPanel = BlockPanel(self)
#     self.wEvent_Size                    do (event: wEvent): self.onResize()
#     self.mButtons[ 0].wEvent_Button     do (): self.onButtonTest()




# wClass(wMainFrame of wFrame):
#   proc onResize(self: wMainFrame, event: wEvent) =
#     self.mMainPanel.size = (event.size.width, event.size.height - self.mStatusBar.size.height)

#   proc init*(self: wMainFrame, newBlockSz: wSize) = 
#     wFrame(self).init(title="Blocks Frame")
    
#     # Create controls
#     self.mMainPanel   = MainPanel(self)

#     let
#       otherWidth  = self.size.width  - self.mMainPanel.mBlockPanel.clientSize.width
#       otherHeight = self.size.height - self.mMainPanel.mBlockPanel.clientSize.height
#       newWidth    = newBlockSz.width  + otherWidth
#       newHeight   = newBlockSz.height + otherHeight + 23

#     # Do stuff
#     self.size = (newWidth, newHeight)
#     gRects = randomizeRectsAll(newBlockSz, 10)

#     # Show!
#     self.center()
#     self.show()



# when isMainModule:
#   randomize()
#   let init_size = (800, 600)
#   let app = App()
#   discard MainFrame(init_size)
#   app.mainLoop()
