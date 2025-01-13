import wNim/[wApp, wMacros, wFrame, wPanel, wEvent, wButton, wBrush,
             wStatusBar, wMenuBar,
             wPaintDC, wMemoryDC, wBitmap]
import std/[bitops, sugar]
import winim, rects


const
  USER_MOUSE_MOVE = WM_APP + 1
  USER_SIZE       = WM_APP + 2

proc EventParam(event: wEvent): tuple = 
  let lo_word:int = event.mLparam.bitand(0x0000_ffff)
  let hi_word:int = event.mLparam.bitand(0xffff_0000).shr(16)
  result = (lo_word, hi_word)

type wBlockPanel = ref object of wPanel
  mRectTable: ref RectTable

wClass(wBlockPanel of wPanel):
  # Declare out-of-order procs
  proc onPaint(self: wBlockPanel, event: wEvent)
  proc init(self: wBlockPanel, parent: wWindow) = 
    wPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
    #self.doubleBuffered = true
    self.wEvent_Paint do (event: wEvent): 
      self.onPaint(event) 
    self.wEvent_MouseMove do (event: wEvent):
      broadcastTopLevelMessage(wBaseApp, USER_MOUSE_MOVE, event.mWparam, event.mLparam)
    self.wEvent_Size do (event: wEvent):
      broadcastTopLevelMessage(wBaseApp, USER_SIZE, event.mWparam, event.mLparam)
  proc onPaint(self: wBlockPanel, event: wEvent) = 
    var dc = PaintDC(event.window)
    let sz = dc.size
    let bmp = Bitmap(sz)
    var memDc = MemoryDC(dc)
    memDc.selectObject(bmp)
    memDc.setBackground(dc.getBackground())
    memDc.clear()
    for rect in self.mRectTable.values():
      memDc.setBrush(Brush(rect.brushcolor))
      memDc.drawRectangle(rect.pos, rect.size)
    dc.blit(0, 0, sz.width, sz.height, memDc)

type wMainPanel = ref object of wPanel
  mBlockPanel: wBlockPanel
  mRectTable: ref RectTable

wClass(wMainPanel of wPanel):
  proc init(self: wMainPanel, parent: wWindow) =
    wPanel(self).init(parent)
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

    b1.wEvent_button do ():
      RandomizeRects(self.mRectTable, self.clientSize)
      self.refresh(false)
    # b2.wEvent_button do ():
      

    proc layout_internal() =
      let 
        (cszw, cszh) = self.clientSize
        bmarg = 8
        (bw, bh) = (130, 30)
        (lbpmarg, rbpmarg, tbpmarg, bbpmarg) = (0, 8, 0, 0)
        butts = [b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15]
      self.mBlockPanel.position = (bw + 2*bmarg + lbpmarg, tbpmarg)
      self.mBlockPanel.size = (cszw - bw - 2*bmarg - lbpmarg - rbpmarg, 
                               cszh - tbpmarg - bbpmarg)
      for i, butt in butts:
        butt.position = (bmarg, bmarg + i * bh)
        butt.size     = (bw, bh)
    layout_internal()
    self.wEvent_Size do (event: wEvent):
      layout_internal()

wClass(wMainFrame of wFrame):
  proc init*(self: wMainFrame, newBlockSz: wSize, rectTable: ref RectTable) = 
    wFrame(self).init(title="Blocks Frame")
    let
      mainPanel = MainPanel(self)
      menuBar   = MenuBar(self)
      menuFile  = Menu(menuBar, "&File")
      statusBar = StatusBar(self)
      otherWidth  = self.size.width  - mainPanel.mBlockPanel.clientSize.width
      otherHeight = self.size.height - mainPanel.mBlockPanel.clientSize.height
      newWidth  = newBlockSz.width  + otherWidth
      newHeight = newBlockSz.height + otherHeight + 23
    mainPanel.mRectTable = rectTable
    mainPanel.mBlockPanel.mRectTable = rectTable
    RandomizeRects(rectTable, newBlockSz)
    self.size = (newWidth, newHeight)
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