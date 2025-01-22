import std/[bitops, sets, tables, sugar]
from std/os import sleep
from std/sequtils import toSeq
import wNim/[wApp, wMacros, wFrame, wPanel, wEvent, wButton, wBrush, wPen,
             wStatusBar, wMenuBar, wSpinCtrl, wStaticText,
             wPaintDC, wMemoryDC, wBitmap, wFont]
from wNim/private/wHelper import `-`
import winim except RECT
import rects, compact

# TODO: copy background before move
# TODO: Hover
# TODO: Figure out invalidate region
# Todo: Figure out why z ordering looks weird when moving mouse

const
  USER_MOUSE_MOVE = WM_APP + 1
  USER_SIZE       = WM_APP + 2
  USER_PAINT_DONE = WM_APP + 3

var 
  MOUSE_DATA: tuple[clickHitIds: seq[RectID],
                    dirtyIds: seq[RectID],
                    hitPos: wPoint,
                    clickpos: wPoint,
                    clearStarted: bool]
  SELECTED: HashSet[RectID]


# These belong in Rects module

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
  mCachedBmps: Table[RectID, ref wBitmap]
  mBigBmp: wBitmap
  mBlendFunc: BLENDFUNCTION
  mMemDc: wMemoryDC
  mBmpDc: wMemoryDC

wClass(wBlockPanel of wPanel):
  proc onResize(self: wBlockPanel, event: wEvent) =
    # Post user message so top frame can show new size
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_SIZE, event.mWparam, event.mLparam)

  proc moveRectsBy(self: wBlockPanel, rectIds: openArray[RectID], delta: wPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    # Determine bounding boxes before and after the move.
    # Redraw what needs to be redrawn
    # This can be done by one of:
    # 1. Do one refresh for each bbox.
    # 2. Do union of bbox and dirty everything inside, then one refresh
    # 3. Redraw everything
    # 4. Render all non-affected blocks as "background" then redraw
    #    just the affected blocks at the new position

    # Here we're doing option 3.  Too many artifacts otherwise
    # FIXME: some artifacts when using kb
    let rects = self.mRectTable[rectIDs]
    # let beforeBbox = bounding_box(rects)
    for rect in rects:
      moveRectBy(rect, delta)
    # let afterBbox = bounding_box(rects)
    # let unionBbox = bounding_box(@[beforeBbox, afterBbox])
    # let dirtyIds = rectInRects(unionBbox, self.mRectTable)
    # MOUSE_DATA.dirtyIds = dirtyIds
    # self.refresh(false, unionBbox)
    self.refresh(false)


  proc onMouseLeftDown(self: wBlockPanel, event: wEvent) =
    MOUSE_DATA.clickpos = event.mousePos
    # This captures all rects under mousept and keeps them
    # even after mouse has moved away from original pos.  Is this
    # what we want?  Or do we want the list to change as the
    # mouse moves around, with the currently top-selected rect
    # a the front of the list?
    let hits = ptInRects(event.mousePos, self.mRectTable)
    if hits.len > 0:
      # Click down on rect
      MOUSE_DATA.hitPos = event.mousePos
      MOUSE_DATA.clickHitIds = hits
      MOUSE_DATA.dirtyIds = rectInRects(hits[^1], self.mRectTable)
      MOUSE_DATA.clearStarted = false
    else: 
      # Click down in clear area
      MOUSE_DATA.clearStarted = true

  proc onMouseMove(self: wBlockPanel, event: wEvent) = 
    # Update message on main frame
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_MOUSE_MOVE, event.mWparam, event.mLparam)
    
    # Todo: hovering over

    let hits = MOUSE_DATA.clickHitIds
    if hits.len == 0: # Just moving around the screen
      return

    # Move rect
    # TODO: create new lastPos
    let delta = event.mousePos - MOUSE_DATA.hitPos
    self.moveRectsBy(@[hits[^1]], delta)
    MOUSE_DATA.hitPos = event.mousePos

  proc updateBmpCache(self: wBlockPanel, id: RectID)
  proc updateBmpCaches(self: wBlockPanel, ids: seq[RectID])
  proc onMouseLeftUp(self: wBlockPanel, event: wEvent) =
    SetFocus(self.mHwnd) # Selects region so it captures keyboard
    if event.mousePos == MOUSE_DATA.clickpos: # released without dragging
      if MOUSE_DATA.clickHitIds.len > 0: # non-drag click-release in a block
        let lastHitId = MOUSE_DATA.clickHitIds[^1]
        MOUSE_DATA.clickHitIds.setLen(0)
        toggle_rect_selection(self.mRectTable, lastHitId)
        self.updateBmpCache(lastHitId)
        self.refresh(false, self.mRectTable[lastHitId].wRect)
      elif MOUSE_DATA.clearStarted: # non-drag click-release in blank space
        # Remember selected rects, deselect, redraw
        if SELECTED.len == 0: return
        MOUSE_DATA.dirtyIds = SELECTED.toSeq
        let dirtyRects = self.mRectTable[MOUSE_DATA.dirtyIds]
        clear_rect_selection(self.mRectTable)
        self.updateBmpCaches(MOUSE_DATA.dirtyIds)

        # Two ways to redraw deselected boxes without
        # redrawing evenything
        if false:
          # Let windows accumulate bounding boxes
          # TODO: figure out how to accumulate regions
          # Pro: it only redraws the deselected boxes
          # Con: there may be some chance that onpaint is
          # called before the refreshed have finished
          # accumulating the regions
          for rect in dirtyRects:
            self.refresh(false, rect.wRect)
        elif true:
          # Add rects that intersect bbox
          # If you don't do this, then stuff inside
          # the bbox of the deselected blocks gets ovedrawn
          # with background.
          # Pro: This has only one refresh call, so only one paint
          # Con: This may draw more blocks than have been deselected.
          let bbox1: wRect = boundingBox(dirtyRects.wRects)
          let allRects: seq[RectId]  = rectInRects(bbox1, self.mRectTable)
          let bbox2: wRect = boundingBox(self.mRectTable[allRects])
          MOUSE_DATA.dirtyIds = allRects
          self.refresh(false, bbox2)

    else: # dragged then released
      MOUSE_DATA.clickHitIds.setLen(0)
  proc onKeyDown(self: wBlockPanel, event: wEvent) = 
    var delta: wPoint
    case event.keyCode
      of wKey_Left:  delta = (-1, 0)
      of wKey_Up:    delta = (0, -1)
      of wKey_Right: delta = (1, 0)
      of wKey_Down:  delta = (0, 1)
      else: return
    self.moveRectsBy(SELECTED.toSeq, delta)


  proc rectToBmp(rect: rects.Rect): wBitmap = 
    # Draw rect and label onto bitmap; return bitmap.
    # Label gets a shrunk down rectangle so it 
    # doesn't overwrite the border
    result = Bitmap(rect.size)
    var memDC = MemoryDC()
    let zeroRect: wRect = (0, 0, rect.width, rect.height)
    var rectstr = $rect.id
    if rect.selected: rectstr &= "*"
    memDC.selectObject(result)
    memDc.setBrush(Brush(rect.brushcolor))
    memDC.drawRectangle(zeroRect)
    memDC.setFont(Font(pointSize=16, wFontFamilyRoman))
    memDC.setTextBackground(rect.brushcolor)
    memDC.drawLabel($rectstr, zeroRect.expand(-1), wCenter or wMiddle)

  proc onPaint(self: wBlockPanel, event: wEvent) = 
    # Make sure in-mem bitmap is initialized to correct size
    var clipRect1: winim.RECT
    GetUpdateRect(self.mHwnd, clipRect1, false)
    var clipRect2: wRect = (x: clipRect1.left - 1, 
                            y: clipRect1.top - 1,
                            width: clipRect1.right - clipRect1.left + 2,
                            height: clipRect1.bottom - clipRect1.top + 2)
    let size = event.window.clientSize
    if isnil(self.mBigBmp) or self.mBigBmp.size != size:
      self.mBigBmp = Bitmap(size)
      self.mMemDc.selectObject(self.mBigBmp)

    # Clear mem, erase old position
    var dirtyRects: seq[Rect]
    if MOUSE_DATA.dirtyIds.len == 0:
      # Draw everything when there is nothing selected
      dirtyRects = self.mRectTable.values.toSeq
      self.mMemDc.clear()
    else:
      dirtyRects = self.mRectTable[MOUSE_DATA.dirtyIds]
      self.mMemDc.setPen(Pen(event.window.backgroundColor))
      self.mMemDc.setBrush(Brush(event.window.backgroundColor))
      self.mMemDc.drawRectangle(clipRect2)

    # Blend cached bitmaps
    #echo "Drawing ", MOUSE_DATA.dirtyIds
    for rect in dirtyRects:
      self.mBmpDc.selectObject(self.mCachedBmps[rect.id][])
      AlphaBlend(self.mMemDc.mHdc, rect.pos.x, rect.pos.y, 
                 rect.size.width, rect.size.height,
                 self.mBmpDC.mHdc, 0, 0,
                 rect.size.width, rect.size.height, self.mBlendFunc)

    # Finally grab DC and do last blit
    var dc = PaintDC(event.window)
    dc.blit(0, 0, dc.size.width, dc.size.height, self.mMemDc)
    MOUSE_DATA.dirtyIds.setLen(0)
    SendMessage(self.mHwnd, USER_PAINT_DONE, 0, 0)

  proc onPaintDone(self: wBlockPanel) =
    if MOUSE_DATA.clearStarted:
      MOUSE_DATA.clearStarted = false

  proc initBmpCache(self: wBlockPanel) =
    # Creates all new bitmaps
    for id, rect in self.mRectTable:
      var bmp: ref wBitmap
      new bmp
      bmp[] = rectToBmp(rect)
      self.mCachedBmps[id] = bmp

  proc updateBmpCache(self: wBlockPanel, id: RectID) =
    # Creates one new bitmap; used for selection
    var bmp: ref wBitmap
    new bmp
    bmp[] = rectToBmp(self.mRectTable[id])
    self.mCachedBmps[id] = bmp

  proc updateBmpCaches(self: wBlockPanel, ids: seq[RectID]) = 
    for id in ids:
      self.updateBmpCache(id)

  proc init(self: wBlockPanel, parent: wWindow, rectTable: RectTable) = 
    wPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
    self.mRectTable = rectTable
    self.initBmpCache()
    self.mBlendFunc = BLENDFUNCTION(BlendOp: AC_SRC_OVER,
                        SourceConstantAlpha: 240,
                        AlphaFormat: 0)
    self.mBmpDC  = MemoryDC()
    self.mMemDc = MemoryDC()
    self.mMemDc.setBackground(self.backgroundColor)

    self.wEvent_Size       do (event: wEvent): self.onResize(event)
    self.wEvent_MouseMove  do (event: wEvent): self.onMouseMove(event)
    self.wEvent_LeftDown   do (event: wEvent): self.onMouseLeftDown(event)
    self.wEvent_LeftUp     do (event: wEvent): self.onMouseLeftUp(event)
    self.wEvent_Paint      do (event: wEvent): self.onPaint(event)
    self.wEvent_KeyDown    do (event: wEvent): self.onKeyDown(event)
    self.USER_PAINT_DONE   do (): self.onPaintDone()





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

  proc onResize(self: wMainPanel) =
      self.Layout()

  proc randomizeRectsAll(self: wMainPanel, qty: int) = 
    randomizeRectsAll(self.mRectTable, self.mBlockPanel.clientSize, qty)
    self.mBlockPanel.initBmpCache()

  proc randomizeRectsPos(self: wMainPanel, qty: int) = 
    randomizeRectsPos(self.mRectTable, self.mBlockPanel.clientSize)

  proc onSpinSpin(self: wMainPanel, event: wEvent) =
    let qty = event.getSpinPos() + event.getSpinDelta()
    self.randomizeRectsAll(qty)
    self.refresh(false)

  proc onSpinTextEnter(self: wMainPanel) =
    if self.mSpnr.value > 0:
      self.randomizeRectsAll(self.mSpnr.value)
      self.refresh(false)

  proc onButtonrandomizeAll(self: wMainPanel) =
    self.randomizeRectsAll(self.mSpnr.value)
    self.refresh(false)

  proc onButtonrandomizePos(self: wMainPanel) =
    self.randomizeRectsPos(self.mSpnr.value)
    self.refresh(false)

  proc onButtonCompact←(self: wMainPanel) =
    echo "←"
    compact(self.mRectTable, X, false)

  proc onButtonCompact→(self: wMainPanel) =
    echo "→"
    compact(self.mRectTable, X, true)

  proc onButtonCompact↑(self: wMainPanel) =
    echo "↑"
    compact(self.mRectTable, Y, false)

  proc onButtonCompact↓(self: wMainPanel) =
    echo "↓"
    compact(self.mRectTable, Y, true)

  proc onButtonCompact←↑(self: wMainPanel) =
    echo "←↑"
    compact(self.mRectTable, X, false)
    compact(self.mRectTable, Y, false)

  proc onButtonCompact←↓(self: wMainPanel) =
    echo "←↓"
    compact(self.mRectTable, X, false)
    compact(self.mRectTable, Y, true)

  proc onButtonCompact→↑(self: wMainPanel) =
    echo "→↑"
    compact(self.mRectTable, X, true)
    compact(self.mRectTable, Y, false)

  proc onButtonCompact→↓(self: wMainPanel) =
    echo "→↓"
    compact(self.mRectTable, X, true)
    compact(self.mRectTable, Y, true)

  proc onButtonCompact↑←(self: wMainPanel) =
    echo "↑←"
    compact(self.mRectTable, Y, false)
    compact(self.mRectTable, X, false)

  proc onButtonCompact↑→(self: wMainPanel) =
    echo "↑→"
    compact(self.mRectTable, Y, false)
    compact(self.mRectTable, X, true)

  proc onButtonCompact↓←(self: wMainPanel) =
    echo "↓←"
    compact(self.mRectTable, Y, true)
    compact(self.mRectTable, X, false)

  proc onButtonCompact↓→(self: wMainPanel) =
    echo "↓→"
    compact(self.mRectTable, Y, true)
    compact(self.mRectTable, X, true)

  proc init(self: wMainPanel, parent: wWindow, rectTable: RectTable, initialRectQty: int) =
    wPanel(self).init(parent)

    # Create controls
    self.mSpnr  = SpinCtrl(self, id=wCommandID(1), value=initialRectQty, style=wAlignRight)
    self.mTxt = StaticText(self, label="Qty", style=wSpRight)
    self.mButtons[ 0] = Button(self, label = "randomize All"     )
    self.mButtons[ 1] = Button(self, label = "randomize Pos"     )
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

    # Connect events
    self.wEvent_Size                    do (event: wEvent): self.onResize()
    self.mSpnr.wEvent_Spin              do (event: wEvent): self.onSpinSpin(event)
    self.mSpnr.wEvent_TextEnter         do (): self.onSpinTextEnter()
    self.mButtons[ 0].wEvent_Button     do (): self.onButtonrandomizeAll()
    self.mButtons[ 1].wEvent_Button     do (): self.onButtonrandomizePos()
    self.mButtons[ 2].wEvent_Button     do (): self.onButtonCompact←()
    self.mButtons[ 3].wEvent_Button     do (): self.onButtonCompact→()
    self.mButtons[ 4].wEvent_Button     do (): self.onButtonCompact↑()
    self.mButtons[ 5].wEvent_Button     do (): self.onButtonCompact↓()
    self.mButtons[ 6].wEvent_Button     do (): self.onButtonCompact←↑()
    self.mButtons[ 7].wEvent_Button     do (): self.onButtonCompact←↓()
    self.mButtons[ 8].wEvent_Button     do (): self.onButtonCompact→↑()
    self.mButtons[ 9].wEvent_Button     do (): self.onButtonCompact→↓()
    self.mButtons[10].wEvent_Button     do (): self.onButtonCompact↑←()
    self.mButtons[11].wEvent_Button     do (): self.onButtonCompact↑→()
    self.mButtons[12].wEvent_Button     do (): self.onButtonCompact↓←()
    self.mButtons[13].wEvent_Button     do (): self.onButtonCompact↓→()




type wMainFrame = ref object of wFrame
  mMainPanel: wMainPanel
  #mMenuBar:   wMenuBar # already defined by wNim
  mMenuFile:  wMenu
  #mStatusBar: wStatusBar # already defined by wNim
wClass(wMainFrame of wFrame):
  proc onResize(self: wMainFrame, event: wEvent) =
    self.mMainPanel.size = (event.size.width, event.size.height - self.mStatusBar.size.height)

  proc onUserSizeNotify(self: wMainFrame, event: wEvent) =
    let lo_word:int = event.getlParam.bitand(0x0000_ffff)
    let hi_word:int = event.getlParam.bitand(0xffff_0000).shr(16)
    let sz:wSize = (lo_word, hi_word)
    self.mStatusBar.setStatusText($sz, index=1)

  proc onUserMouseNotify(self: wMainFrame, event: wEvent) =
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
    randomizeRectsAll(rectTable, newBlockSz, self.mMainPanel.mSpnr.value)
    self.mMainPanel.mBlockPanel.initBmpCache()


    # Connect Events
    self.wEvent_Size     do (event: wEvent): self.onResize(event)
    self.USER_SIZE       do (event: wEvent): self.onUserSizeNotify(event)
    self.USER_MOUSE_MOVE do (event: wEvent): self.onUserMouseNotify(event)

    # Show!
    self.center()
    self.show()



