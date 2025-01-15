import wNim/[wApp, wMacros, wFrame, wPanel, wEvent, wButton, wBrush,
             wStatusBar, wMenuBar, wSpinCtrl, wStaticText, wIconImage,
             wPaintDC, wMemoryDC, wBitmap, wFont]
import std/[bitops, sets, strformat]
from winim import nil
import tables, rects


const
  USER_MOUSE_MOVE = winim.WM_APP + 1
  USER_SIZE       = winim.WM_APP + 2

var 
  MOUSE_DATA: tuple[ids: seq[RectID],
                    lastpos: wPoint,
                    clickpos: wPoint,
                    clear_pending: bool]
  SELECTED: HashSet[RectID]


# Perhaps these belong in another module like db, selection, interaction, etc.
proc hittest(pos: wPoint, table: ref RectTable): seq[RectID] = 
  for id, rect in table:
    let lrcorner: wPoint = (rect.pos.x + rect.size.width,
                            rect.pos.y + rect.size.height)
    if pos.x >= rect.pos.x and pos.x <= lrcorner.x and
       pos.y >= rect.pos.y and pos.y <= lrcorner.y:
        result.add(id)

proc toggle_rect_selection(table: ref RectTable, id: RectID) = 
  if table[id].selected:
    table[id].selected = false
    SELECTED.excl(id)
  else:
    table[id].selected = true
    SELECTED.incl(id)

proc clear_rect_selection(table: ref RectTable) = 
  for id in SELECTED:
    table[id].selected = false
  SELECTED.clear()


type wBlockPanel = ref object of wPanel
  mRefRectTable: ref RectTable
  #mCachedBmps: Table[RectID, ref wBitmap]
wClass(wBlockPanel of wPanel):
  proc OnResize(self: wBlockPanel, event: wEvent) =
    # Post user message so top frame can show new size
    let hWnd = winim.GetAncestor(self.handle, winim.GA_ROOT)
    winim.SendMessage(hWnd, USER_SIZE, event.mWparam, event.mLparam)

  proc OnMouseMove(self: wBlockPanel, event: wEvent) = 
    # Update message on main frame
    let hWnd = winim.GetAncestor(self.handle, winim.GA_ROOT)
    winim.SendMessage(hWnd, USER_MOUSE_MOVE, event.mWparam, event.mLparam)
    
    # Move rect
    let hits = MOUSE_DATA.ids
    if hits.len == 0: return
    var rect = self.mRefRectTable[hits[^1]]
    MoveRect(rect, MOUSE_DATA.lastpos, event.mousePos)
    MOUSE_DATA.lastpos = event.mousePos
    self.refresh(false)

  proc OnMouseLeftDown(self: wBlockPanel, event: wEvent) =
    MOUSE_DATA.clickpos = event.mousePos
    let hits = hittest(event.mousePos, self.mRefRectTable)
    if hits.len > 0:
      MOUSE_DATA.ids = hits
      MOUSE_DATA.lastpos = event.mousePos
      MOUSE_DATA.clear_pending = false
    else:
      MOUSE_DATA.clear_pending = true

  proc OnMouseLeftUp(self: wBlockPanel, event: wEvent) =
    if event.mousePos == MOUSE_DATA.clickpos: # Click and release without moving
      if MOUSE_DATA.ids.len > 0:
        toggle_rect_selection(self.mRefRectTable, MOUSE_DATA.ids[^1])
      elif MOUSE_DATA.clear_pending:
        clear_rect_selection(self.mRefRectTable)
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
    let bf = winim.BLENDFUNCTION(BlendOp: winim.AC_SRC_OVER,
                                SourceConstantAlpha: 0x7f,
                                AlphaFormat: 0)

    var memDc = MemoryDC(dc)
    memDc.selectObject(Bitmap(dc.size))
    memDc.setBackground(dc.getBackground())
    memDc.clear()

    var bmpDC = MemoryDC(dc)
    for rect in self.mRefRectTable.values():
      bmpDC.selectObject(RectToBmp(rect))
      winim.AlphaBlend(memDc.mHdc, rect.pos.x, rect.pos.y, 
                       rect.size.width, rect.size.height,
                       bmpDC.mHdc, 0, 0,
                       rect.size.width, rect.size.height,
                       bf )
    #winim.DwmFlush()
    dc.blit(0, 0, dc.size.width, dc.size.height, memDc)




  
  # proc InitBmpCache() =
  #   for id, rect in self.mRefRectTable:
  #     let bmp = Bitmap(rect.size)
  #     var memDC = MemoryDC()
  #     let font = 

  proc init(self: wBlockPanel, parent: wWindow, refRectTable: ref RectTable) = 
    wPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
    self.mRefRectTable = refRectTable
    #self.InitBmpCache()
    self.wEvent_Size       do (event: wEvent): self.OnResize(event)
    self.wEvent_MouseMove  do (event: wEvent): self.OnMouseMove(event)
    self.wEvent_LeftDown   do (event: wEvent): self.OnMouseLeftDown(event)
    self.wEvent_LeftUp     do (event: wEvent): self.OnMouseLeftUp(event)
    self.wEvent_Paint      do (event: wEvent): self.OnPaint(event) 





type wMainPanel = ref object of wPanel
  mBlockPanel: wBlockPanel
  mRefRectTable: ref RectTable
  mSpnr: wSpinCtrl
  mTxt:  wStaticText
  mB1:   wButton
  mB2:   wButton
  mB3:   wButton
  mB4:   wButton
  mB5:   wButton
  mB6:   wButton
  mB7:   wButton
  mB8:   wButton
  mB9:   wButton
  mB10:  wButton
  mB11:  wButton
  mB12:  wButton
  mB13:  wButton
  mB14:  wButton
  mB15:  wButton
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

  proc init(self: wMainPanel, parent: wWindow, refRectTable: ref RectTable) =
    wPanel(self).init(parent)

    # Create controls
    self.mSpnr  = SpinCtrl(self, id=wCommandID(1), value=QTY, style=wAlignRight)
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
    self.wEvent_Size            do (event: wEvent): self.OnResize()
    self.mSpnr.wEvent_Spin      do (event: wEvent): self.OnSpinSpin(event)
    self.mSpnr.wEvent_TextEnter do (event: wEvent): self.OnSpinTextEnter(event)
    self.mB1.wEvent_Button      do (): self.OnButtonRandomize()
    self.mB2.wEvent_Button      do (): self.OnButtonCompact←()
    self.mB3.wEvent_Button      do (): self.OnButtonCompact→()
    self.mB4.wEvent_Button      do (): self.OnButtonCompact↑()
    self.mB5.wEvent_Button      do (): self.OnButtonCompact↓()
    self.mB6.wEvent_Button      do (): self.OnButtonCompact←↑()
    self.mB7.wEvent_Button      do (): self.OnButtonCompact←↓()
    self.mB8.wEvent_Button      do (): self.OnButtonCompact→↑()
    self.mB9.wEvent_Button      do (): self.OnButtonCompact→↓()
    self.mB10.wEvent_Button     do (): self.OnButtonCompact↑←()
    self.mB11.wEvent_Button     do (): self.OnButtonCompact↑→()
    self.mB12.wEvent_Button     do (): self.OnButtonCompact↓←()
    self.mB13.wEvent_Button     do (): self.OnButtonCompact↓→()




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

  proc init*(self: wMainFrame, newBlockSz: wSize, refRectTable: ref RectTable) = 
    wFrame(self).init(title="Blocks Frame")
    
    # Create controls
    self.mMainPanel   = MainPanel(self, refRectTable)
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
    self.mStatusBar.setStatusText($newBlockSz, index=1) # Cheat: set this directly on startup

    # Connect Events
    self.wEvent_Size     do (event: wEvent): self.OnResize(event)
    self.USER_SIZE       do (event: wEvent): self.OnUserSizeNotify(event)
    self.USER_MOUSE_MOVE do (event: wEvent): self.OnUserMouseNotify(event)

    # Show!
    self.center()
    self.show()



