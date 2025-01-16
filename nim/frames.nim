import wNim/[wApp, wMacros, wFrame, wPanel, wEvent, wButton, wBrush,
             wStatusBar, wMenuBar, wSpinCtrl, wStaticText, wIconImage,
             wPaintDC, wMemoryDC, wBitmap, wFont]
import std/[bitops, sets, strformat]
import winim
import tables, rects


const
  USER_MOUSE_MOVE = WM_APP + 1
  USER_SIZE       = WM_APP + 2

var 
  MOUSE_DATA: tuple[ids: seq[RectID],
                    lastpos: wPoint,
                    clickpos: wPoint,
                    clear_pending: bool]
  SELECTED: HashSet[RectID]


# Perhaps these belong in another module like db, selection, interaction, etc.
proc hittest(pos: wPoint, table: RectTable): seq[RectID] = 
  for id, rect in table:
    let lrcorner: wPoint = (rect.pos.x + rect.size.width,
                            rect.pos.y + rect.size.height)
    if pos.x >= rect.pos.x and pos.x <= lrcorner.x and
       pos.y >= rect.pos.y and pos.y <= lrcorner.y:
        result.add(id)

proc toggle_rect_selection(table: RectTable, id: RectID) = 
  if table[id].selected:
    table[id].selected = false
    SELECTED.excl(id)
  else:
    table[id].selected = true
    SELECTED.incl(id)

proc clear_rect_selection(table: RectTable) = 
  for id in SELECTED:
    table[id].selected = false
  SELECTED.clear()


type wBlockPanel = ref object of wPanel
  mRectTable: RectTable
  #mCachedBmps: Table[RectID, ref wBitmap]
wClass(wBlockPanel of wPanel):
  proc OnResize(self: wBlockPanel, event: wEvent) =
    # Post user message so top frame can show new size
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_SIZE, event.mWparam, event.mLparam)

  proc OnMouseMove(self: wBlockPanel, event: wEvent) = 
    # Update message on main frame
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_MOUSE_MOVE, event.mWparam, event.mLparam)
    
    # Move rect
    let hits = MOUSE_DATA.ids
    if hits.len == 0: return
    var rect = self.mRectTable[hits[^1]]
    MoveRect(rect, MOUSE_DATA.lastpos, event.mousePos)
    MOUSE_DATA.lastpos = event.mousePos
    self.refresh(false)

  proc OnMouseLeftDown(self: wBlockPanel, event: wEvent) =
    MOUSE_DATA.clickpos = event.mousePos
    let hits = hittest(event.mousePos, self.mRectTable)
    if hits.len > 0:
      MOUSE_DATA.ids = hits
      MOUSE_DATA.lastpos = event.mousePos
      MOUSE_DATA.clear_pending = false
    else:
      MOUSE_DATA.clear_pending = true

  proc OnMouseLeftUp(self: wBlockPanel, event: wEvent) =
    if event.mousePos == MOUSE_DATA.clickpos: # Click and release without moving
      if MOUSE_DATA.ids.len > 0:
        toggle_rect_selection(self.mRectTable, MOUSE_DATA.ids[^1])
      elif MOUSE_DATA.clear_pending:
        clear_rect_selection(self.mRectTable)
        MOUSE_DATA.clear_pending = false
    MOUSE_DATA.ids.setLen(0)
    self.refresh(false)

  proc RectToBmp(rect: rects.Rect): wBitmap = 
    result = Bitmap(rect.size)
    var memDC = MemoryDC()
    memDC.selectObject(result)
    memDC.setFont(Font(pointSize=16, wFontFamilyRoman))
    memDc.setBrush(Brush(rect.brushcolor))
    memDC.setTextBackground(rect.brushcolor)
    memDC.drawRectangle((0, 0), rect.size)
    let labelRect: wRect = (x:0, y:0, width: rect.size.width, height: rect.size.height)
    memDC.drawLabel($rect.id, labelRect, wCenter or wMiddle)

  proc OnPaint(self: wBlockPanel, event: wEvent) = 
    var dc = PaintDC(event.window)
    let bf = BLENDFUNCTION(BlendOp: AC_SRC_OVER,
                                SourceConstantAlpha: 0x7f,
                                AlphaFormat: 0)

    var memDc = MemoryDC(dc)
    memDc.selectObject(Bitmap(dc.size))
    memDc.setBackground(dc.getBackground())
    memDc.clear()

    var bmpDC = MemoryDC(dc)
    for rect in self.mRectTable.values():
      bmpDC.selectObject(RectToBmp(rect))
      AlphaBlend(memDc.mHdc, rect.pos.x, rect.pos.y, 
                       rect.size.width, rect.size.height,
                       bmpDC.mHdc, 0, 0,
                       rect.size.width, rect.size.height, bf)
    #DwmFlush()
    dc.blit(0, 0, dc.size.width, dc.size.height, memDc)



  # proc InitBmpCache() =
  #   for id, rect in self.mRefRectTable:
  #     let bmp = Bitmap(rect.size)
  #     var memDC = MemoryDC()
  #     let font = 

  proc init(self: wBlockPanel, parent: wWindow, rectTable: RectTable) = 
    wPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
    self.mRectTable = rectTable
    #self.InitBmpCache()
    self.wEvent_Size       do (event: wEvent): self.OnResize(event)
    self.wEvent_MouseMove  do (event: wEvent): self.OnMouseMove(event)
    self.wEvent_LeftDown   do (event: wEvent): self.OnMouseLeftDown(event)
    self.wEvent_LeftUp     do (event: wEvent): self.OnMouseLeftUp(event)
    self.wEvent_Paint      do (event: wEvent): self.OnPaint(event) 





type wMainPanel = ref object of wPanel
  mBlockPanel: wBlockPanel
  mRectTable: RectTable
  mSpnr: wSpinCtrl
  mTxt:  wStaticText
  mButtons: array[16, wButton]

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
    let smallw = bw div 2
    self.mTxt.position = (bmarg, bmarg)
    self.mTxt.size = (smallw, self.mTxt.size.height)

    # Spin Ctrl position, size
    self.mSpnr.position = (bmarg + (bw div 2), bmarg)
    self.mSpnr.size     = (smallw, self.mSpnr.size.height)

    # Buttons position, size
    for i, butt in self.mButtons:
      butt.position = (bmarg, bmarg + (i+1) * bh)
      butt.size     = (bw, bh)

  proc OnResize(self: wMainPanel) =
      self.Layout()

  proc RandomizeRectsAll(self: wMainPanel, qty: int) = 
    RandomizeRectsAll(self.mRectTable, self.mBlockPanel.clientSize, qty)

  proc RandomizeRectsPos(self: wMainPanel, qty: int) = 
    RandomizeRectsPos(self.mRectTable, self.mBlockPanel.clientSize)

  proc OnSpinSpin(self: wMainPanel, event: wEvent) =
    let qty = event.getSpinPos() + event.getSpinDelta()
    self.RandomizeRectsAll(qty)
    self.refresh(false)

  proc OnSpinTextEnter(self: wMainPanel) =
    if self.mSpnr.value > 0:
      self.RandomizeRectsAll(self.mSpnr.value)
      self.refresh(false)

  proc OnButtonRandomizeAll(self: wMainPanel) =
    self.RandomizeRectsAll(self.mSpnr.value)
    self.refresh(false)

  proc OnButtonRandomizePos(self: wMainPanel) =
    self.RandomizeRectsPos(self.mSpnr.value)
    self.refresh(false)

  proc OnButtonCompact←(self: wMainPanel) =
    echo "←"

  proc OnButtonCompact→(self: wMainPanel) =
    echo "→"

  proc OnButtonCompact↑(self: wMainPanel) =
    echo "↑"

  proc OnButtonCompact↓(self: wMainPanel) =
    echo "↓"

  proc OnButtonCompact←↑(self: wMainPanel) =
    echo "←↑"

  proc OnButtonCompact←↓(self: wMainPanel) =
    echo "←↓"

  proc OnButtonCompact→↑(self: wMainPanel) =
    echo "→↑"

  proc OnButtonCompact→↓(self: wMainPanel) =
    echo "→↓"

  proc OnButtonCompact↑←(self: wMainPanel) =
    echo "↑←"

  proc OnButtonCompact↑→(self: wMainPanel) =
    echo "↑→"

  proc OnButtonCompact↓←(self: wMainPanel) =
    echo "↓←"

  proc OnButtonCompact↓→(self: wMainPanel) =
    echo "↓→"

  proc init(self: wMainPanel, parent: wWindow, rectTable: RectTable, initialRectQty: int) =
    wPanel(self).init(parent)

    # Create controls
    self.mSpnr  = SpinCtrl(self, id=wCommandID(1), value=initialRectQty, style=wAlignRight)
    self.mTxt = StaticText(self, label="Qty", style=wSpRight)
    self.mButtons[ 0] = Button(self, label = "Randomize All"     )
    self.mButtons[ 1] = Button(self, label = "Randomize Pos"     )
    self.mButtons[ 2] = Button(self, label = "Compact X←"        )
    self.mButtons[ 3] = Button(self, label = "Compact X→"        )
    self.mButtons[ 4] = Button(self, label = "Compact Y↑"        )
    self.mButtons[ 5] = Button(self, label = "Compact Y↓"        )
    self.mButtons[ 6] = Button(self, label = "Compact X← then Y↑")
    self.mButtons[ 7] = Button(self, label = "Compact X← then Y↓")
    self.mButtons[ 8] = Button(self, label = "Compact X→ then Y↑")
    self.mButtons[ 9] = Button(self, label = "Compact X→ then Y↓")
    self.mButtons[10] = Button(self, label = "Compact Y↑ then X←")
    self.mButtons[11] = Button(self, label = "Compact Y↑ then X→")
    self.mButtons[12] = Button(self, label = "Compact Y↓ then X←")
    self.mButtons[13] = Button(self, label = "Compact Y↓ then X→")
    self.mButtons[14] = Button(self, label = "Save"              )
    self.mButtons[15] = Button(self, label = "Load"              )

    # Set up stuff
    self.mRectTable = rectTable
    self.mBlockPanel = BlockPanel(self, rectTable)
    self.mSpnr.setRange(1, 10000)
    #self.RandomizeRects(self.mSpnr.value)
    #RandomizeRects(self.mRectTable, self.clientSize, self.mSpnr.value)

    # Connect events
    self.wEvent_Size            do (event: wEvent): self.OnResize()
    self.mSpnr.wEvent_Spin      do (event: wEvent): self.OnSpinSpin(event)
    self.mSpnr.wEvent_TextEnter do (): self.OnSpinTextEnter()
    self.mButtons[0].wEvent_Button      do (): self.OnButtonRandomizeAll()
    self.mButtons[1].wEvent_Button      do (): self.OnButtonRandomizePos()
    self.mButtons[2].wEvent_Button      do (): self.OnButtonCompact←()
    self.mButtons[3].wEvent_Button      do (): self.OnButtonCompact→()
    self.mButtons[4].wEvent_Button      do (): self.OnButtonCompact↑()
    self.mButtons[5].wEvent_Button      do (): self.OnButtonCompact↓()
    self.mButtons[6].wEvent_Button      do (): self.OnButtonCompact←↑()
    self.mButtons[7].wEvent_Button      do (): self.OnButtonCompact←↓()
    self.mButtons[8].wEvent_Button      do (): self.OnButtonCompact→↑()
    self.mButtons[9].wEvent_Button      do (): self.OnButtonCompact→↓()
    self.mButtons[10].wEvent_Button     do (): self.OnButtonCompact↑←()
    self.mButtons[11].wEvent_Button     do (): self.OnButtonCompact↑→()
    self.mButtons[12].wEvent_Button     do (): self.OnButtonCompact↓←()
    self.mButtons[13].wEvent_Button     do (): self.OnButtonCompact↓→()




type wMainFrame = ref object of wFrame
  mMainPanel: wMainPanel
  #mMenuBar:   wMenuBar # already defined by wNim
  mMenuFile:  wMenu
  #mStatusBar: wStatusBar # already defined by wNim
wClass(wMainFrame of wFrame):
  proc OnResize(self: wMainFrame, event: wEvent) =
    self.mMainPanel.size = (event.size.width, event.size.height - self.mStatusBar.size.height)

  proc OnUserSizeNotify(self: wMainFrame, event: wEvent) =
    let lo_word:int = event.getlParam.bitand(0x0000_ffff)
    let hi_word:int = event.getlParam.bitand(0xffff_0000).shr(16)
    let sz:wSize = (lo_word, hi_word)
    self.mStatusBar.setStatusText($sz, index=1)

  proc OnUserMouseNotify(self: wMainFrame, event: wEvent) =
    self.mStatusBar.setStatusText($event.mouseScreenPos, 2)

  proc init*(self: wMainFrame, newBlockSz: wSize, rectTable: var RectTable) = 
    wFrame(self).init(title="Blocks Frame")
    
    # Create controls
    self.mMainPanel   = MainPanel(self, rectTable, QTY)
    self.mMenuBar     = MenuBar(self)
    self.mMenuFile    = Menu(self.mMenuBar, "&File")
    self.mStatusBar   = StatusBar(self)

    let
      otherWidth  = self.size.width  - self.mMainPanel.mBlockPanel.clientSize.width
      otherHeight = self.size.height - self.mMainPanel.mBlockPanel.clientSize.height
      newWidth    = newBlockSz.width  + otherWidth
      newHeight   = newBlockSz.height + otherHeight + 23

    # Do stuff
    self.size = (newWidth, newHeight)
    self.mMenuFile.append(1, "Open")
    self.mStatusBar.setStatusWidths([-2, -1, 100])
    
    # A couple of cheats because I'm not sure how to do these when the mBlockPanel is 
    # finally rendered at the proper size
    self.mStatusBar.setStatusText($newBlockSz, index=1)
    RandomizeRectsAll(rectTable, newBlockSz, self.mMainPanel.mSpnr.value)
    #self.mMainPanel.mSpnr.setValue(QTY)
    #self.mMainPanel.OnSpinTextEnter()


    # Connect Events
    self.wEvent_Size     do (event: wEvent): self.OnResize(event)
    self.USER_SIZE       do (event: wEvent): self.OnUserSizeNotify(event)
    self.USER_MOUSE_MOVE do (event: wEvent): self.OnUserMouseNotify(event)

    # Show!
    self.center()
    self.show()



