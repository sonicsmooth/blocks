# TEST!!
import std/[locks, segfaults, sets, strformat, tables ]
from std/os import sleep
from std/sequtils import toSeq
# import wNim/[wApp, wMacros, wFrame, wPanel, wEvent, wButton, wBrush, wPen,
#              wStatusBar, wMenuBar, wSpinCtrl, wStaticText, wCheckBox, wSlider,
#              wPaintDC, wMemoryDC, wBitmap, wFont]
import wNim
from wNim/private/wHelper import `-`
import winim except RECT
import anneal, compact, rects, userMessages
import concurrent

# TODO: copy background before move
# TODO: Hover
# TODO: Figure out invalidate region
# TODO: Implement rotation
# TODO: update qty when spinner text loses focus
# TODO: checkbox for show intermediate steps
# TODO: select by rectangle


type 
  wBlockPanel = ref object of wPanel
    mRectTable: RectTable
    mCachedBmps: Table[RectID, ref wBitmap]
    mRatio: float
    mBigBmp: wBitmap
    mBlendFunc: BLENDFUNCTION
    mMemDc: wMemoryDC
    mBmpDc: wMemoryDC
    mAllBbox: wRect
    mSelectBox: wRect
    mText: string

  wMainPanel = ref object of wPanel
    mBlockPanel: wBlockPanel
    mRectTable: RectTable
    mSpnr: wSpinCtrl
    mTxt:  wStaticText
    mChk:  wCheckBox
    mBox1: wStaticBox
    mBox2: wStaticBox
    mRad1: wRadioButton
    mRad2: wRadioButton
    mRad3: wRadioButton
    mRad4: wRadioButton
    mSldr: wSlider
    mButtons: array[17, wButton]

  wMainFrame = ref object of wFrame
    mMainPanel: wMainPanel
    #mMenuBar:   wMenuBar # already defined by wNim
    mMenuFile:  wMenu
    #mStatusBar: wStatusBar # already defined by wNim

  Command = enum
    Move
    Delete
    Rotate
  
  MouseState = enum
    None
    LmbDownInRect
    LmbDownInSpace
    CtrlLmbDownInRect
    CtrlLmbDownInSpace
    ShftLmbDownInRect
    ShftLmbDownInSpace
    DraggingRect
    DraggingSelect

var 
  MOUSE_DATA: tuple[clickHitIds:      seq[RectID],
                    dirtyIds:         seq[RectID],
                    hitPos:           wPoint,
                    clickPos:         wPoint,
                    lastPos:          wPoint,
                    dragRectStarted:  bool,
                    selectBoxStarted: bool]
  SELECTED: HashSet[RectID]

proc lParamTuple[T](event: wEvent): auto {.inline.} =
  (LOWORD(event.getlParam).T,
   HIWORD(event.getlParam).T)


proc toggleRectSelect(table: RectTable, id: RectID) = 
  if table[id].selected:
    table[id].selected = false
    SELECTED.excl(id)
  else:
    table[id].selected = true
    SELECTED.incl(id)

proc toggleRectSelect(table: RectTable, ids: seq[RectId] | HashSet[RectId]) =
  # Todo: check if this copies openArray, or add when... case
  let sel = ids.toSeq
  for id in sel:
    toggleRectSelect(table, id)

proc toggleRectSelect(table: RectTable) =
    let sel = SELECTED.toSeq
    for id in sel:
      toggleRectSelect(table, id)



proc clearRectSelect(table: RectTable, id: RectID) =
  table[id].selected = false
  SELECTED.excl(id)

proc clearRectSelect(table: RectTable, ids: seq[RectId] | HashSet[RectId]) =
  # Todo: check if this copies openArray, or add when... case
  let sel = ids.toSeq
  for id in sel: table[id].selected = false
  for id in sel: SELECTED.excl(id)

proc clearRectSelect(table: RectTable) = 
  let sel = SELECTED.toSeq
  for id in sel: table[id].selected = false
  SELECTED.clear()



proc setRectSelect(table: RectTable, id: RectID) =
  table[id].selected = true
  SELECTED.incl(id)

proc setRectSelect(table: RectTable, ids: seq[RectId] | HashSet[RectId]) =
  # Todo: check if this copies openArray, or add when... case
  let sel = ids.toSeq
  for id in sel: table[id].selected = true
  for id in sel: SELECTED.incl(id)

proc setRectSelect(table: RectTable) = 
  let sel = SELECTED.toSeq
  for id in sel: table[id].selected = true
  for id in sel: SELECTED.incl(id)


proc normalizeSelectRect(rect: var wRect, startPos, endPos: wPoint) =
  # make sure that rect.x,y is always upper left
  let (sx,sy) = startPos
  let (ex,ey) = endPos
  rect.x = min(sx, ex)
  rect.y = min(sy, ey)
  rect.width = abs(ex - sx)
  rect.height = abs(ey - sy)


wClass(wBlockPanel of wPanel):
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
    memDC.drawLabel(rectstr, zeroRect.expand(-1), wCenter or wMiddle)
  proc forceRedraw(self: wBlockPanel, wait: int) = 
    self.refresh(false)
    UpdateWindow(self.mHwnd)
    if wait > 0: sleep(wait)
  proc initBmpCaches(self: wBlockPanel) =
    # Creates all new bitmaps
    echo "initcaches"
    writeStackTrace()
    # TODO: check if ref is needed;  wBitmap is already a ref object
    self.mCachedBmps.clear()
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
  proc updateBmpCaches(self: wBlockPanel, ids: seq[RectID] | HashSet[RectId]) = 
    for id in ids.toSeq:
      self.updateBmpCache(id)
  proc boundingBox(self: wBlockPanel) = 
    self.mAllBbox = boundingBox(self.mRectTable.values.toSeq)
  proc onResize(self: wBlockPanel, event: wEvent) =
    # Post user message so top frame can show new size
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_SIZE, event.mWparam, event.mLparam)
  proc updateRatio(self: wBlockPanel) =
    let ratio = self.mRectTable.fillRatio
    if ratio != self.mRatio:
      echo ratio
      self.mRatio = ratio
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
    self.mAllBbox = boundingBox(self.mRectTable.values.toSeq)
    self.updateRatio()
    self.refresh(false)
  proc deleteRects(self: wBlockPanel, rectIds: openArray[RectID]) =
    for id in rectIds:
      echo "deleting ", id
      self.mRectTable.del(id)
      self.mCachedBmps.del(id)
      SELECTED.excl(id)
    self.mAllBbox = boundingBox(self.mRectTable.values.toSeq)
    self.updateRatio()
    self.refresh(false)
  proc rotateRects(self: wBlockPanel, rectIds: openArray[RectID]) =
    for id in rectIds:
      echo "rotating ", id
    self.mAllBbox = boundingBox(self.mRectTable.values.toSeq)
    self.updateRatio()
    self.refresh(false)
  
  proc onMouseLeftDown(self: wBlockPanel, event: wEvent) =
    defer:
      echo MOUSE_DATA

    MOUSE_DATA.clickPos = event.mousePos
    MOUSE_DATA.lastPos  = event.mousePos
    # This captures all rects under mousept and keeps the list
    # even after mouse has moved away from original pos.  Is this
    # what we want?  Or do we want the list to change as the
    # mouse moves around, with the currently top-selected rect
    # a the front of the list?
    # Also, for ptInRects, maybe we only want to return a single ID,
    # so which one is that?  The highest number?  The first returned
    # from the table?  The top of the layer stack?
    let hits = ptInRects(event.mousePos, self.mRectTable)
    if hits.len > 0:
      # Click down on rect
      MOUSE_DATA.clickHitIds = hits
      MOUSE_DATA.dirtyIds = rectInRects(hits[^1], self.mRectTable)
      MOUSE_DATA.dragRectStarted = true
    else: 
      # Click down in clear area
      MOUSE_DATA.selectBoxStarted = true

  proc onMouseMove(self: wBlockPanel, event: wEvent) = 
    # Update message on main frame
    defer:
      let hWnd = GetAncestor(self.handle, GA_ROOT)
      SendMessage(hWnd, USER_MOUSE_MOVE, event.mWparam, event.mLparam)

    # Todo: hovering over

    # Move rect or draw selection box
    if MOUSE_DATA.dragRectStarted:
      let delta = event.mousePos - MOUSE_DATA.lastPos
      let hits = MOUSE_DATA.clickHitIds
      self.moveRectsBy(@[hits[^1]], delta)
    elif MOUSE_DATA.selectBoxStarted:
      normalizeSelectRect(self.mSelectBox, MOUSE_DATA.clickPos, event.mousePos)
      let rectsInBox = rectInRects(self.mSelectBox, self.mRectTable)
      echo rectsInBox
      setRectSelect(self.mRectTable, rectsInBox)
      self.updateBmpCaches(rectsInBox)
      self.refresh(false) # TODO optimize what gets invalidated
    
    MOUSE_DATA.lastPos = event.mousePos
    

  proc onMouseLeftUp(self: wBlockPanel, event: wEvent) =
    defer:
      echo MOUSE_DATA

    SetFocus(self.mHwnd) # Selects region so it captures keyboard
    if event.mousePos == MOUSE_DATA.clickPos: # released without dragging
      # Non-drag click-release in a block:
      # Clear all previous selections if not ctrl
      # Toggle selection
      # Clear dragBoxStarted and selectBoxStarted
      if MOUSE_DATA.dragRectStarted:
        MOUSE_DATA.dragRectStarted = false
        let lastHitId = MOUSE_DATA.clickHitIds[^1]
        MOUSE_DATA.clickHitIds.setLen(0)
        MOUSE_DATA.dirtyIds.setLen(0)
        var others = SELECTED
        others.excl(lastHitId)
        if not event.ctrlDown:
          clearRectSelect(self.mRectTable, others)
          MOUSE_DATA.dirtyIds = others.toSeq
        toggleRectSelect(self.mRectTable, lastHitId)
        MOUSE_DATA.dirtyIds.add(lastHitId)
        self.updateBmpCaches(MOUSE_DATA.dirtyIds)
        self.refresh(false)

      # non-drag click-release in blank space
      # Clear all selections
      # Remember selected rects, deselect, redraw
      elif MOUSE_DATA.selectBoxStarted: 
        MOUSE_DATA.selectBoxStarted = false
        if SELECTED.len == 0:
          return
        MOUSE_DATA.dirtyIds = SELECTED.toSeq
        clearRectSelect(self.mRectTable)
        self.updateBmpCaches(MOUSE_DATA.dirtyIds)

        # Two ways to redraw deselected boxes without
        # redrawing evenything
        let dirtyRects = self.mRectTable[MOUSE_DATA.dirtyIds]
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
          let bbox1       = boundingBox(dirtyRects.wRects)
          let rectsInBbox = rectInRects(bbox1, self.mRectTable)
          let bbox2       = boundingBox(self.mRectTable[rectsInBbox])
          MOUSE_DATA.dirtyIds = rectsInBbox
          self.refresh(false, bbox2)

    else: # dragged then released
      MOUSE_DATA.selectBoxStarted = false
      MOUSE_DATA.clickHitIds.setLen(0)
      MOUSE_DATA.dragRectStarted = false

    # In any case, clear selection rectangle
    self.mSelectBox.x = 0
    self.mSelectBox.y = 0
    self.mSelectBox.width = 0
    self.mSelectBox.height = 0
    self.refresh(false)
  
  proc onKeyDown(self: wBlockPanel, event: wEvent) = 
    const cmdLookup = {wKey_Left:   Move,   wKey_Up:    Move,
                       wKey_Right:  Move,   wKey_Down:  Move,
                       wKey_Delete: Delete, wKey_Space: Rotate}.toTable
    const moveLookup: array[wKey_Left .. wKey_Down, wPoint] =
      [(-1,0), (0, -1), (1, 0), (0, 1)]
    if not (event.keyCode in cmdLookup):
      return
    case cmdLookup[event.keyCode]:
    of Move: self.moveRectsBy(SELECTED.toSeq, moveLookup[event.keyCode])
    of Delete: self.deleteRects(SELECTED.toSeq)
    of Rotate: self.rotateRects(SELECTED.toSeq)
  
  proc onPaint(self: wBlockPanel, event: wEvent) = 
    # Do this to make sure we only get called once per event
    var dc = PaintDC(event.window)

    if not tryAcquire(gLock):
      return

    # TODO: Move this to where it is used
    var clipRect1: winim.RECT
    GetUpdateRect(self.mHwnd, clipRect1, false)
    var clipRect2: wRect = (x: clipRect1.left - 1, 
                            y: clipRect1.top - 1,
                            width: clipRect1.right - clipRect1.left + 2,
                            height: clipRect1.bottom - clipRect1.top + 2)

    # Make sure in-mem bitmap is initialized to correct size
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
    for rect in dirtyRects:
      self.mBmpDc.selectObject(self.mCachedBmps[rect.id][])
      AlphaBlend(self.mMemDc.mHdc, rect.pos.x, rect.pos.y, 
                 rect.size.width, rect.size.height,
                 self.mBmpDC.mHdc, 0, 0,
                 rect.size.width, rect.size.height, self.mBlendFunc)

    # draw bounding box for everything
    self.mMemDC.setPen(Pen(wBlack))
    self.mMemDc.setBrush(wTransparentBrush)
    self.mMemDc.drawRectangle(self.mAllBbox)

    # Draw selection box
    echo self.mSelectBox
    self.mMemDC.setPen(Pen(wBlue))
    self.mMemDc.setBrush(wTransparentBrush)
    self.mMemDc.drawRectangle(self.mSelectBox)

    # draw text sent from other thread
    let sw = self.mMemDc.charWidth * self.mText.len
    let ch = self.mMemDc.charHeight
    let textRect = (self.clientSize.width-sw, self.clientSize.height-ch, sw, ch)
    self.mMemDc.setBrush(Brush(wBlack))
    self.mMemDC.setTextBackground(self.backgroundColor)
    self.mMemDC.setFont(Font(pointSize=16, wFontFamilyRoman))
    self.mMemDC.drawLabel(self.mText, textRect, wMiddle)

    
    # Finally grab DC and do last blit
    dc.blit(0, 0, dc.size.width, dc.size.height, self.mMemDc)
    MOUSE_DATA.dirtyIds.setLen(0)
    #SendMessage(self.mHwnd, USER_PAINT_DONE, 0, 0)
    release(gLock)
  
  proc onPaintDone(self: wBlockPanel) =
    if MOUSE_DATA.dragRectStarted:
      MOUSE_DATA.dragRectStarted = false
  proc init(self: wBlockPanel, parent: wWindow, rectTable: RectTable) = 
    wPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
    self.mRectTable = rectTable
    #self.initBmpCaches()
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


wClass(wMainPanel of wPanel):
  proc layout(self: wMainPanel) =
    let 
      (cszw, cszh) = self.clientSize
      bmarg = 8
      (bw, bh) = (130, 30)
      (lbpmarg, rbpmarg, tbpmarg, bbpmarg) = (0, 8, 0, 0)
    self.mBlockPanel.position = (bw + 2*bmarg + lbpmarg, tbpmarg)
    self.mBlockPanel.size = (cszw - bw - 2*bmarg - lbpmarg - rbpmarg, 
                             cszh - tbpmarg - bbpmarg)
    var yPosAcc = 0
    # Static text position, size
    let smallw = bw div 2
    self.mTxt.position = (bmarg, bmarg)
    self.mTxt.size = (smallw, self.mTxt.size.height)

    # Spin Ctrl position, size
    self.mSpnr.position = (bmarg + (bw div 2), bmarg)
    self.mSpnr.size     = (smallw, self.mSpnr.size.height)
    yPosAcc += bmarg + self.mTxt.size.height

    # Checkbox position, size
    self.mChk.position = (bmarg, yPosAcc + bmarg)
    self.mChk.size     = (bw, bh)
    yPosAcc += bmarg + bh

    # Slider position, size
    self.mSldr.position = (bmarg, yPosAcc + bmarg)
    self.mSldr.size    = (bw, bh)
    yPosAcc += bmarg + bh

    # Static box1 and radio button position, size
    self.mBox1.position = (bmarg, yPosAcc + bmarg)
    self.mRad1.position = (bmarg*2, yPosAcc + bmarg*3)
    self.mRad2.position = (bmarg*2, yPosAcc + bmarg*3 + self.mRad1.size.height)
    self.mBox1.size = (bw, self.mRad1.size.height + bmarg +
                           self.mRad2.size.height + bmarg*2)
    yPosAcc += bmarg + self.mBox1.size.height

    # Static box2 position, size
    self.mBox2.position = (bmarg, yPosAcc + bmarg)
    self.mRad3.position = (bmarg*2, yPosAcc + bmarg*3)
    self.mRad4.position = (bmarg*2, yPosAcc + bmarg*3 + self.mRad3.size.height)
    self.mBox2.size = (bw, self.mRad3.size.height + bmarg +
                           self.mRad4.size.height + bmarg*2)
    yPosAcc += bmarg + self.mBox2.size.height

    # Buttons position, size
    for i, butt in self.mButtons:
      butt.position = (bmarg, yPosAcc)
      butt.size     = (bw, bh)
      yPosAcc += bh
  proc randomizeRectsAll(self: wMainPanel, qty: int) = 
    rects.randomizeRectsAll(self.mRectTable, self.mBlockPanel.clientSize, qty)
    self.mBlockPanel.initBmpCaches()

  proc delegate1DButtonCompact(self: wMainPanel, axis: Axis, reverse: bool) = 
    withLock(gLock):
      compact(self.mRectTable, axis, reverse, self.mBlockPanel.clientSize)
      self.mBlockPanel.boundingBox()
    self.mBlockPanel.updateRatio()
    self.refresh(false)

  proc delegate2DButtonCompact(self: wMainPanel, direction: CompactDir) =
    if gCompactThread.running:
      return
    for i in gAnnealComms.low .. gAnnealComms.high:
      if gAnnealComms[i].thread.running:
        return
    if self.mChk.value: # Do anneal
      proc compactfn() {.closure.} = 
        iterCompact(self.mRectTable, direction, self.mBlockPanel.clientSize)
      let 
        strat = 
          if self.mRad1.value: Strat1
          else:                Strat2
        perturbFn = if self.mRad3.value:
          makeWiggler[PosTable, ptr RectTable](self.mBlockPanel.clientSize)
        else:
          makeSwapper[PosTable, ptr RectTable]()
      for i in gAnnealComms.low .. gAnnealComms.high:
        let arg: AnnealArg = (pRectTable: self.mRectTable.addr,
                              strategy:   strat,
                              initTemp:   self.mSldr.value.float,
                              perturbFn:  perturbFn,
                              compactFn:  compactfn,
                              window:     self,
                              comm:       gAnnealComms[i])
        gAnnealComms[i].thread.createThread(annealMain, arg)
        break
    else: # Not anneal, just normal 2d compact
      let arg: CompactArg = (pRectTable: self.mRectTable.addr, 
                            direction:   direction,
                            window:      self,
                            screenSize:  self.mBlockPanel.clientSize)
      gCompactThread.createThread(compactWorker, arg)
      gCompactThread.joinThread()
      self.refresh(false)

  proc onResize(self: wMainPanel) =
      self.layout()
  proc onSpinSpin(self: wMainPanel, event: wEvent) =
    let qty = event.getSpinPos() + event.getSpinDelta()
    self.randomizeRectsAll(qty)
    self.mBlockPanel.boundingBox()
    self.mBlockPanel.updateRatio()
    self.refresh(false)
  proc onSpinTextEnter(self: wMainPanel) =
    if self.mSpnr.value > 0:
      self.randomizeRectsAll(self.mSpnr.value)
      self.mBlockPanel.boundingBox()
      self.mBlockPanel.updateRatio()
      self.refresh(false)
  proc onCheckBox(self: wMainPanel, event: wEvent) =
    if self.mChk.value:
      self.mSldr.enable()
      self.mRad1.enable()
      self.mRad2.enable()
      self.mRad3.enable()
      self.mRad4.enable()
    else:
      self.mSldr.disable()
      self.mRad1.disable()
      self.mRad2.disable()
      self.mRad3.disable()
      self.mRad4.disable()
  proc onSlider(self: wMainPanel, event: wEvent) =
    let pos = event.scrollPos
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hwnd, USER_SLIDER, pos, pos)
  proc onButtonrandomizeAll(self: wMainPanel) =
    self.randomizeRectsAll(self.mSpnr.value)
    self.mBlockPanel.boundingBox()
    self.mBlockPanel.updateRatio()
    self.refresh(false)
  proc onButtonrandomizePos(self: wMainPanel) =
    let sz = self.mBlockPanel.clientSize
    rects.randomizeRectsPos(self.mRectTable, sz)
    self.mBlockPanel.boundingBox()
    self.mBlockPanel.updateRatio()
    self.refresh(false)
  proc onButtonCompact←(self: wMainPanel) =
    self.delegate1DButtonCompact(X, false)
  proc onButtonCompact→(self: wMainPanel) =
    self.delegate1DButtonCompact(X, true)
  proc onButtonCompact↑(self: wMainPanel) =
    self.delegate1DButtonCompact(Y, false)
  proc onButtonCompact↓(self: wMainPanel) =
    self.delegate1DButtonCompact(Y, true)
  proc onButtonCompact←↑(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, false, false))
  proc onButtonCompact←↓(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, false, true))
  proc onButtonCompact→↑(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, true, false))
  proc onButtonCompact→↓(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, true, true))
  proc onButtonCompact↑←(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, false, false))
  proc onButtonCompact↑→(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, false, true))
  proc onButtonCompact↓←(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, true, false))
  proc onButtonCompact↓→(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, true, true))
  var ackCnt: int
  proc onAlgUpdate(self: wMainPanel, event: wEvent) =
    let (idx, _) = lParamTuple[int](event)
    let (msgAvail, msg) = gAnnealComms[idx].sendChan.tryRecv()
    if msgAvail:
        self.mBlockPanel.mText = $idx & ": " & msg 
    withLock(gLock):
      self.mBlockPanel.boundingBox()
      self.mBlockPanel.forceRedraw(0)
      gAnnealComms[idx].ackChan.send(ackCnt)
    inc ackCnt
    
  proc init(self: wMainPanel, parent: wWindow, rectTable: RectTable, initialRectQty: int) =
    wPanel(self).init(parent)

    # Create controls
    self.mSpnr  = SpinCtrl(self, id=wCommandID(1), value=initialRectQty, style=wAlignRight)
    self.mTxt   = StaticText(self, label="Qty", style=wSpRight)
    self.mChk   = CheckBox(self, label="Anneal", style=wChkAlignRight)
    self.mBox1  = StaticBox(self, label="Strategy")
    self.mBox2  = StaticBox(self, label="Perturb Func")
    self.mRad1  = RadioButton(self, label="Strat1", style=wRbGroup)
    self.mRad2  = RadioButton(self, label="Strat2")
    self.mRad3  = RadioButton(self, label="Wiggle", style=wRbGroup)
    self.mRad4  = RadioButton(self, label="Swap")
    self.mSldr  = Slider(self)
    self.mButtons[ 0] = Button(self, label = "randomize All"     )
    self.mButtons[ 1] = Button(self, label = "randomize Pos"     )
    self.mButtons[ 2] = Button(self, label = "Test"              )
    self.mButtons[ 3] = Button(self, label = "Compact X←"        )
    self.mButtons[ 4] = Button(self, label = "Compact X→"        )
    self.mButtons[ 5] = Button(self, label = "Compact Y↑"        )
    self.mButtons[ 6] = Button(self, label = "Compact Y↓"        )
    self.mButtons[ 7] = Button(self, label = "Compact X← then Y↑")
    self.mButtons[ 8] = Button(self, label = "Compact X← then Y↓")
    self.mButtons[ 9] = Button(self, label = "Compact X→ then Y↑")
    self.mButtons[10] = Button(self, label = "Compact X→ then Y↓")
    self.mButtons[11] = Button(self, label = "Compact Y↑ then X←")
    self.mButtons[12] = Button(self, label = "Compact Y↑ then X→")
    self.mButtons[13] = Button(self, label = "Compact Y↓ then X←")
    self.mButtons[14] = Button(self, label = "Compact Y↓ then X→")
    self.mButtons[15] = Button(self, label = "Save"              )
    self.mButtons[16] = Button(self, label = "Load"              )

    # Set up stuff
    self.mRectTable = rectTable
    self.mBlockPanel = BlockPanel(self, rectTable)
    self.mSpnr.setRange(1, 10000)
    self.mSldr.setValue(20)
    self.mChk.setValue(true)
    self.mRad1.click()
    self.mRad3.click()

    # Connect events
    self.wEvent_Size                    do (event: wEvent): self.onResize()
    self.mSpnr.wEvent_Spin              do (event: wEvent): self.onSpinSpin(event)
    self.mSpnr.wEvent_TextEnter         do (): self.onSpinTextEnter()
    self.mChk.wEvent_CheckBox           do (event: wEvent): self.onCheckBox(event)
    self.mSldr.wEvent_Slider            do (event: wEvent): self.onSlider(event)
    self.mButtons[ 0].wEvent_Button     do (): self.onButtonrandomizeAll()
    self.mButtons[ 1].wEvent_Button     do (): self.onButtonrandomizePos()
    #self.mButtons[ 2].wEvent_Button     do (): self.onButtonTest()
    self.mButtons[ 3].wEvent_Button     do (): self.onButtonCompact←()
    self.mButtons[ 4].wEvent_Button     do (): self.onButtonCompact→()
    self.mButtons[ 5].wEvent_Button     do (): self.onButtonCompact↑()
    self.mButtons[ 6].wEvent_Button     do (): self.onButtonCompact↓()
    self.mButtons[ 7].wEvent_Button     do (): self.onButtonCompact←↑()
    self.mButtons[ 8].wEvent_Button     do (): self.onButtonCompact←↓()
    self.mButtons[ 9].wEvent_Button     do (): self.onButtonCompact→↑()
    self.mButtons[10].wEvent_Button     do (): self.onButtonCompact→↓()
    self.mButtons[11].wEvent_Button     do (): self.onButtonCompact↑←()
    self.mButtons[12].wEvent_Button     do (): self.onButtonCompact↑→()
    self.mButtons[13].wEvent_Button     do (): self.onButtonCompact↓←()
    self.mButtons[14].wEvent_Button     do (): self.onButtonCompact↓→()
    self.USER_ALG_UPDATE                do (event: wEvent): self.onAlgUpdate(event)



wClass(wMainFrame of wFrame):
  proc onResize(self: wMainFrame, event: wEvent) =
    self.mMainPanel.size = (event.size.width, event.size.height - self.mStatusBar.size.height)
  proc onUserSizeNotify(self: wMainFrame, event: wEvent) =
    let sz: wSize = lParamTuple[int](event)
    self.mStatusBar.setStatusText($sz, index=1)
  proc onUserMouseNotify(self: wMainFrame, event: wEvent) =
    let mousePos: wPoint = lParamTuple[int](event)
    self.mStatusBar.setStatusText($mousePos, index=2)
  proc onUserSliderNotify(self: wMainFrame, event: wEvent) =
    let tmpStr = &"temperature: {event.mLparam}"
    self.mStatusBar.setStatusText(tmpStr, index=0)
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
    let sldrVal = self.mMainPanel.mSldr.value
    let tmpStr = &"temperature: {sldrVal}"
    self.mStatusBar.setStatusText(tmpStr, index=0)
    rects.randomizeRectsAll(rectTable, newBlockSz, self.mMainPanel.mSpnr.value)
    self.mMainPanel.mBlockPanel.mAllBbox = boundingBox(self.mMainPanel.mRectTable.values.toSeq)
    self.mMainPanel.mBlockPanel.initBmpCaches()


    # Connect Events
    self.wEvent_Size     do (event: wEvent): self.onResize(event)
    self.USER_SIZE       do (event: wEvent): self.onUserSizeNotify(event)
    self.USER_MOUSE_MOVE do (event: wEvent): self.onUserMouseNotify(event)
    self.USER_SLIDER     do (event: wEvent): self.onUserSliderNotify(event)

    # Show!
    self.center()
    self.show()



