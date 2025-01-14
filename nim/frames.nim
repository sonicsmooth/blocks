import wNim/[wApp, wMacros, wFrame, wPanel, wEvent, wButton, wBrush,
             wStatusBar, wMenuBar, wSpinCtrl, wStaticText,
             wPaintDC, wMemoryDC, wBitmap]
import std/[bitops]
import winim, rects





const
  USER_MOUSE_MOVE = WM_APP + 1
  USER_SIZE       = WM_APP + 2

proc EventParam(event: wEvent): tuple = 
  let lp = event.getlParam
  let lo_word:int = lp.bitand(0x0000_ffff)
  let hi_word:int = lp.bitand(0xffff_0000).shr(16)
  result = (lo_word, hi_word)


type wBlockPanel = ref object of wPanel
  mRefRectTable: ref RectTable

wClass(wBlockPanel of wPanel):
  proc OnResize(self: wBlockPanel, event: wEvent) =
    # Post user message so top frame can show new size
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_SIZE, event.mWparam, event.mLparam)
  proc OnMouseMove(self: wBlockPanel, event: wEvent) = 
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_MOUSE_MOVE, event.mWparam, event.mLparam)
  proc OnPaint(self: wBlockPanel, event: wEvent) = 
    var dc = PaintDC(event.window)
    let sz = dc.size
    let bmp = Bitmap(sz)
    var memDc = MemoryDC(dc)
    memDc.selectObject(bmp)
    memDc.setBackground(dc.getBackground())
    memDc.clear()
    for rect in self.mRefRectTable.values():
      memDc.setBrush(Brush(rect.brushcolor))
      memDc.drawRectangle(rect.pos, rect.size)
    dc.blit(0, 0, sz.width, sz.height, memDc)
  proc init(self: wBlockPanel, parent: wWindow, refRectTable: ref RectTable) = 
    wPanel(self).init(parent, style=wBorderSimple)
    self.mRefRectTable = refRectTable
    self.backgroundColor = wLightBlue
    self.wEvent_Size      do (event: wEvent): self.OnResize(event)
    self.wEvent_MouseMove do (event: wEvent): self.OnMouseMove(event)
    self.wEvent_Paint     do (event: wEvent): self.OnPaint(event) 









type wMainPanel = ref object of wPanel
  mBlockPanel: wBlockPanel
  mRefRectTable: ref RectTable
  mSpnr:  wSpinCtrl
  mTxt: wStaticText
  mB1:  wButton
  mB2:  wButton
  mB3:  wButton
  mB4:  wButton
  mB5:  wButton
  mB6:  wButton
  mB7:  wButton
  mB8:  wButton
  mB9:  wButton
  mB10: wButton
  mB11: wButton
  mB12: wButton
  mB13: wButton
  mB14: wButton
  mB15: wButton

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
    # Static text position, size
    self.mTxt.position = (bmarg, bmarg+8)
    self.mTxt.size     = (bw div 2, bh)

    # Spin Ctrl position, size
    self.mSpnr.position = (bmarg + (bw div 2), bmarg)
    self.mSpnr.size     = (bw div 2, bh)

    # Buttons position, size
    let  butts = [self.mB1, self.mB2, self.mB3, self.mB4, self.mB5, self.mB6, self.mB7, self.mB8,
                  self.mB9, self.mB10, self.mB11, self.mB12, self.mB13, self.mB14, self.mB15]
    for i, butt in butts:
      butt.position = (bmarg, bmarg + (i+1) * bh)
      butt.size     = (bw, bh)
  proc OnResize(self: wMainPanel) =
      self.Layout()
  proc OnSpinSpin(self: wMainPanel, event: wEvent) =
    let val = event.getSpinPos() + event.getSpinDelta()
    RandomizeRects(self.mRefRectTable, self.clientSize, val)
    self.refresh(false)
  proc OnSpinTextEnter(self: wMainPanel, event: wEvent) =
    if self.mSpnr.value > 0:
      RandomizeRects(self.mRefRectTable, self.clientSize, self.mSpnr.value)
      self.refresh(false)
  proc OnButtonRandomize(self: wMainPanel) =
    RandomizeRects(self.mRefRectTable, self.clientSize, self.mSpnr.value)
    self.refresh(false)
  proc init(self: wMainPanel, parent: wWindow, refRectTable: ref RectTable) =
    wPanel(self).init(parent)

    # Create controls
    self.mSpnr  = SpinCtrl(self, id=wCommandID(1), value=10, style=wAlignRight)
    self.mTxt = StaticText(self, label="Qty", style=wSpRight)
    self.mB1  = Button(self, label = "Randomize"         )
    self.mB2  = Button(self, label = "Compact X←"        )
    self.mB3  = Button(self, label = "Compact X→"        )
    self.mB4  = Button(self, label = "Compact Y↑"        )
    self.mB5  = Button(self, label = "Compact Y↓"        )
    self.mB6  = Button(self, label = "Compact X← then Y↑")
    self.mB7  = Button(self, label = "Compact X← then Y↓")
    self.mB8  = Button(self, label = "Compact X→ then Y↑")
    self.mB9  = Button(self, label = "Compact X→ then Y↓")
    self.mB10 = Button(self, label = "Compact Y↑ then X←")
    self.mB11 = Button(self, label = "Compact Y↑ then X→")
    self.mB12 = Button(self, label = "Compact Y↓ then X←")
    self.mB13 = Button(self, label = "Compact Y↓ then X→")
    self.mB14 = Button(self, label = "Save"              )
    self.mB15 = Button(self, label = "Load"              )

    # Set up stuff
    self.mRefRectTable = refRectTable
    self.mBlockPanel = BlockPanel(self, refRectTable)
    self.mSpnr.setRange(1, 10000)
    RandomizeRects(self.mRefRectTable, self.clientSize, self.mSpnr.value)

    # Connect events
    self.wEvent_Size          do (event: wEvent): self.OnResize()
    self.mSpnr.wEvent_Spin      do (event: wEvent): self.OnSpinSpin(event)
    self.mSpnr.wEvent_TextEnter do (event: wEvent): self.OnSpinTextEnter(event)
    self.mB1.wEvent_button    do ():              self.OnButtonRandomize()











wClass(wMainFrame of wFrame):
  proc init*(self: wMainFrame, newBlockSz: wSize, refRectTable: ref RectTable) = 
    wFrame(self).init(title="Blocks Frame")
    let
      mainPanel = MainPanel(self, refRectTable)
      menuBar   = MenuBar(self)
      menuFile  = Menu(menuBar, "&File")
      statusBar = StatusBar(self)
      otherWidth  = self.size.width  - mainPanel.mBlockPanel.clientSize.width
      otherHeight = self.size.height - mainPanel.mBlockPanel.clientSize.height
      newWidth  = newBlockSz.width  + otherWidth
      newHeight = newBlockSz.height + otherHeight + 23

    self.size = (newWidth, newHeight)
    menuFile.append(1, "Open")
    statusBar.setStatusWidths([-2, -1, 100])

    self.wEvent_Size do (e: wEvent):
      mainPanel.size = (e.size.width, e.size.height - statusBar.size.height)
    self.USER_SIZE do (e: wEvent): 
      #statusBar.setStatusText($e.EventParam.wSize, 1)
      statusBar.setStatusText($wSize(e.EventParam), 1)
    self.USER_MOUSE_MOVE do (e: wEvent): 
      #statusBar.setStatusText($e.mMousePos, 2)
      statusBar.setStatusText($e.mouseScreenPos, 2)

    self.center()
    self.show()



