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
# TODO: change temperature slider during run if checkbox
# TODO: gray out slider or use it as max starting temp


type 
  wBlockPanel = ref object of wPanel
    mRectTable: RectTable
    mCachedBmps: Table[RectID, ref wBitmap]
    mBigBmp: wBitmap
    mBlendFunc: BLENDFUNCTION
    mMemDc: wMemoryDC
    mBmpDc: wMemoryDC
    mAllBbox: wRect
    mText: string

  wMainPanel = ref object of wPanel
    mBlockPanel: wBlockPanel
    mRectTable: RectTable
    mSpnr: wSpinCtrl
    mTxt:  wStaticText
    mChk:  wCheckBox
    mSldr: wSlider
    mButtons: array[17, wButton]

  wMainFrame = ref object of wFrame
    mMainPanel: wMainPanel
    #mMenuBar:   wMenuBar # already defined by wNim
    mMenuFile:  wMenu
    #mStatusBar: wStatusBar # already defined by wNim


var 
  MOUSE_DATA: tuple[clickHitIds:  seq[RectID],
                    dirtyIds:     seq[RectID],
                    hitPos:       wPoint,
                    clickpos:     wPoint,
                    clearStarted: bool]
  SELECTED: HashSet[RectID]

proc lParamTuple[T](event: wEvent): auto {.inline.} =
  (LOWORD(event.getlParam).T,
   HIWORD(event.getlParam).T)
proc toggleRectSelection(table: RectTable, id: RectID) = 
  if table[id].selected:
    table[id].selected = false
    SELECTED.excl(id)
  else:
    table[id].selected = true
    SELECTED.incl(id)
proc clearRectSelection(table: RectTable) = 
  for id in SELECTED:
    table[id].selected = false
  SELECTED.clear()


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
  proc updateBmpCaches(self: wBlockPanel, ids: seq[RectID]) = 
    for id in ids:
      self.updateBmpCache(id)
  proc boundingBox(self: wBlockPanel) = 
    self.mAllBbox = boundingBox(self.mRectTable.values.toSeq)
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
    self.mAllBbox = boundingBox(self.mRectTable.values.toSeq)
    self.refresh(false)
  proc onMouseLeftDown(self: wBlockPanel, event: wEvent) =
    MOUSE_DATA.clickpos = event.mousePos
    # This captures all rects under mousept and keeps the
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

    # DEBUG
    # let pir = ptInRects(event.mousePos, self.mRectTable)
    # if pir.len > 0:
    #   echo pir
    #   echo self.mRectTable

    # Todo: hovering over

    let hits = MOUSE_DATA.clickHitIds
    if hits.len == 0: # Just moving around the screen
      return

    # Move rect
    # TODO: create new lastPos
    let delta = event.mousePos - MOUSE_DATA.hitPos
    self.moveRectsBy(@[hits[^1]], delta)
    MOUSE_DATA.hitPos = event.mousePos
    echo self.mRectTable.fillRatio
  proc onMouseLeftUp(self: wBlockPanel, event: wEvent) =
    SetFocus(self.mHwnd) # Selects region so it captures keyboard
    if event.mousePos == MOUSE_DATA.clickpos: # released without dragging
      if MOUSE_DATA.clickHitIds.len > 0: # non-drag click-release in a block
        let lastHitId = MOUSE_DATA.clickHitIds[^1]
        MOUSE_DATA.clickHitIds.setLen(0)
        toggleRectSelection(self.mRectTable, lastHitId)
        self.updateBmpCache(lastHitId)
        self.refresh(false, self.mRectTable[lastHitId].wRect)
      elif MOUSE_DATA.clearStarted: # non-drag click-release in blank space
        # Remember selected rects, deselect, redraw
        if SELECTED.len == 0:
          MOUSE_DATA.clearStarted = false
          return
        MOUSE_DATA.dirtyIds = SELECTED.toSeq
        let dirtyRects = self.mRectTable[MOUSE_DATA.dirtyIds]
        clearRectSelection(self.mRectTable)
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
          let bbox1       = boundingBox(dirtyRects.wRects)
          let rectsInBbox = rectInRects(bbox1, self.mRectTable)
          let bbox2       = boundingBox(self.mRectTable[rectsInBbox])
          MOUSE_DATA.dirtyIds = rectsInBbox
          self.refresh(false, bbox2)

    else: # dragged then released
      MOUSE_DATA.clickHitIds.setLen(0)
      MOUSE_DATA.clearStarted = false
  proc onKeyDown(self: wBlockPanel, event: wEvent) = 
    var delta: wPoint
    case event.keyCode
      of wKey_Left:  delta = (-1, 0)
      of wKey_Up:    delta = (0, -1)
      of wKey_Right: delta = (1, 0)
      of wKey_Down:  delta = (0, 1)
      else: return
    self.moveRectsBy(SELECTED.toSeq, delta)
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
    if MOUSE_DATA.clearStarted:
      MOUSE_DATA.clearStarted = false
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

    # Buttons position, size
    for i, butt in self.mButtons:
      butt.position = (bmarg, yPosAcc)
      butt.size     = (bw, bh)
      yPosAcc += bh
  proc randomizeRectsAll(self: wMainPanel, qty: int) = 
    rects.randomizeRectsAll(self.mRectTable, self.mBlockPanel.clientSize, qty)
    self.mBlockPanel.initBmpCaches()

  proc delegate1DButtonCompact(self: wMainPanel, axis: Axis, reverse: bool) = 
    compact(self.mRectTable, axis, reverse, self.mBlockPanel.clientSize)
    self.mBlockPanel.boundingBox()
    self.refresh(false)

  proc delegate2DButtonCompact(self: wMainPanel,
                               primax, secax: Axis,
                               primrev, secrev: bool) =
    if not self.mChk.value:
      let arg: CompactArg = (pRectTable: self.mRectTable.addr, 
                             primax:     primax,
                             secax:      secax,
                             primrev:    primrev,
                             secrev:     secrev,
                             window:     self,
                             screenSize: self.mBlockPanel.clientSize)
      if not gCompactThread.running:
        gCompactThread.createThread(compactWorker, arg)
    else:
      let 
        wigSwpn = true
        str1Str2n = true
        compactfn = proc() {.closure.} = 
          iterCompact(self.mRectTable, primax, secax, primrev, secrev,
                      self.mBlockPanel.clientSize)
        perturbFn = 
          if wigSwpn: makeWiggler[PosTable, ptr RectTable](self.mBlockPanel.clientSize)
          else:       makeSwapper[PosTable, ptr RectTable]()
        strat =
          if str1Str2n: Strat1
          else:         Strat2
      for i in gAnnealComms.low..gAnnealComms.high:
        gAnnealComms[i].idx = i
        let arg: AnnealArg = (pRectTable: self.mRectTable.addr,
                              strategy:   strat,
                              perturbFn:  perturbFn,
                              compactFn:  compactfn,
                              window:     self,
                              comm:       gAnnealComms[i])
        # if gAnnealThreads[i].running:
        #   continue
        
        gAnnealComms[i].thread.createThread(annealMain, arg)
        let h = gAnnealComms[i].thread.handle
        echo &"Started threadIdx {i} with handle {h}"
        # break

      

  proc onResize(self: wMainPanel) =
      self.layout()
  proc onSpinSpin(self: wMainPanel, event: wEvent) =
    let qty = event.getSpinPos() + event.getSpinDelta()
    self.randomizeRectsAll(qty)
    self.mBlockPanel.boundingBox()
    self.refresh(false)
  proc onSpinTextEnter(self: wMainPanel) =
    if self.mSpnr.value > 0:
      self.randomizeRectsAll(self.mSpnr.value)
      self.mBlockPanel.boundingBox()
      self.refresh(false)
  proc onSlider(self: wMainPanel, event: wEvent) =
    let pos = event.scrollPos
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hwnd, USER_SLIDER, pos, pos)
  proc onButtonrandomizeAll(self: wMainPanel) =
    self.randomizeRectsAll(self.mSpnr.value)
    self.mBlockPanel.boundingBox()
    self.refresh(false)
  proc onButtonrandomizePos(self: wMainPanel) =
    let sz = self.mBlockPanel.clientSize
    rects.randomizeRectsPos(self.mRectTable, sz)
    self.mBlockPanel.boundingBox()
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
    self.delegate2DButtonCompact(X, Y, false, false)
  proc onButtonCompact←↓(self: wMainPanel) =
    self.delegate2DButtonCompact(X, Y, false, true)
  proc onButtonCompact→↑(self: wMainPanel) =
    self.delegate2DButtonCompact(X, Y, true, false)
  proc onButtonCompact→↓(self: wMainPanel) =
    self.delegate2DButtonCompact(X, Y, true, true)
  proc onButtonCompact↑←(self: wMainPanel) =
    self.delegate2DButtonCompact(Y, X, false, false)
  proc onButtonCompact↑→(self: wMainPanel) =
    self.delegate2DButtonCompact(Y, X, false, true)
  proc onButtonCompact↓←(self: wMainPanel) =
    self.delegate2DButtonCompact(Y, X, true, false)
  proc onButtonCompact↓→(self: wMainPanel) =
    self.delegate2DButtonCompact(Y, X, true, true)
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

    # Connect events
    self.wEvent_Size                    do (event: wEvent): self.onResize()
    self.mSpnr.wEvent_Spin              do (event: wEvent): self.onSpinSpin(event)
    self.mSpnr.wEvent_TextEnter         do (): self.onSpinTextEnter()
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



