import wNim/[wApp, wMacros, wFrame, wPanel, wEvent, wButton, wPaintDC, wBrush,
             wStatusBar, wMenuBar,]
import std/[random, bitops]
import winim, rects


const
  USER_MOUSE_MOVE = WM_APP + 1
  USER_SIZE       = WM_APP + 2

proc EventParam(event: wEvent): tuple = 
  let lo_word:int = event.mLparam.bitand(0x0000_ffff)
  let hi_word:int = event.mLparam.bitand(0xffff_0000).shr(16)
  result = (lo_word, hi_word)

type wBlockPanel = ref object of wPanel
  mRectTable: RectTable

wClass(wBlockPanel of wPanel):
  # Declare out-of-order procs
  proc onPaint(self: wBlockPanel, event: wEvent)

  proc init(self: wBlockPanel, parent: wWindow) = 
    wPanel(self).init(parent)
    self.backgroundColor = parent.backgroundColor
    self.doubleBuffered = true
    self.setDoubleBuffered(true)
    self.wEvent_Paint do (event: wEvent): 
      self.onPaint(event) 
    self.wEvent_MouseMove do (event: wEvent):
      broadcastTopLevelMessage(wBaseApp, USER_MOUSE_MOVE, event.mWparam, event.mLparam)
    self.wEvent_Size do (event: wEvent):
      broadcastTopLevelMessage(wBaseApp, USER_SIZE, event.mWparam, event.mLparam)

  proc onPaint(self: wBlockPanel, event: wEvent) = 
    var dc = PaintDC(event.window)
    for rect in self.mRectTable.values():
      setBrush(dc, Brush(rect.brushcolor))
      drawRectangle(dc, rect.pos, rect.size)


type wMainPanel = ref object of wPanel
  mBlockPanel: wBlockPanel

wClass(wMainPanel of wPanel):
  proc init(self: wMainPanel, parent: wWindow) =
    wPanel(self).init(parent, style=wBorderSimple)
    self.mBlockPanel = BlockPanel(self)
    let
      b1  = Button(self, label = "Randomize"         )
      b2  = Button(self, label = "Compact X←"        )
      b3  = Button(self, label = "Compact X→"        )
      b4  = Button(self, label = "Compact Y↑"        )
      b5  = Button(self, label = "Compact Y↓"        )
      b6  = Button(self, label = "Compact X← then Y↑")
      b7  = Button(self, label = "Compact X← then Y↓")
      b8  = Button(self, label = "Compact X→ then Y↑")
      b9  = Button(self, label = "Compact X→ then Y↓")
      b10 = Button(self, label = "Compact Y↑ then X←")
      b11 = Button(self, label = "Compact Y↑ then X→")
      b12 = Button(self, label = "Compact Y↓ then X←")
      b13 = Button(self, label = "Compact Y↓ then X→")
      b14 = Button(self, label = "Save"              )
      b15 = Button(self, label = "Load"              )

    proc layout_internal() =
      let 
        (cszw, cszh) = self.clientSize
        bmarg = 8
        bw = 130
        bh = 30
        butts = [b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15]
      self.mBlockPanel.position = (bw + 2*bmarg, 0)
      self.mBlockPanel.size = (cszw - bw - 2*bmarg, cszh)
      for i, butt in butts:
        butt.position = (bmarg, bmarg + i * bh)
        butt.size     = (bw, bh)
    layout_internal()
    self.wEvent_Size do(event: wEvent):
      layout_internal()

wClass(wMainFrame of wFrame):
  proc init*(self: wMainFrame, rectTable: RectTable) = 
    wFrame(self).init(title="Blocks Frame", size=(800,600))
    let
      mainPanel = MainPanel(self)
      menuBar = MenuBar(self)
      menuFile = Menu(menuBar, "&File")
      statusBar = StatusBar(self)
    echo "setting"
    mainPanel.mBlockPanel.mRectTable = rectTable
    echo "done setting"
    menuFile.append(1, "Open")
    statusBar.setStatusWidths([-2, -1, 100])
    self.center()
    self.show()

    self.wEvent_Size do (e: wEvent): 
      mainPanel.size = (e.size.width, e.size.height - statusBar.size.height)
    self.USER_SIZE do (e: wEvent): 
      statusBar.setStatusText($e.EventParam.wSize, 1)
    self.USER_MOUSE_MOVE do (e: wEvent): 
      statusBar.setStatusText($e.mMousePos, 2)


when isMainModule:
  let app = App()
  let mainFrame = MainFrame()
  discard mainFrame
  randomize()
  app.mainLoop()