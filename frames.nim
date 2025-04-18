import std/[algorithm, locks, math, segfaults, sets, sugar, strformat, tables ]
from std/sequtils import toSeq, foldl
from std/os import sleep
import wNim
import winim
from wNim/private/wHelper import `-`
import anneal, compact, concurrent, rects, recttable, sdlframes
import stack, userMessages, utils
import timeit

# TODO: copy background before Move
# TODO: Hover
# TODO: Figure out invalidate region
# TODO: update qty when spinner text loses focus
# TODO: checkbox for show intermediate steps
# TODO: Load up system colors from HKEY_CURRENT_USER\Control Panel\Colors
# TODO: Separate options panel for packing


type
  CacheKey = tuple[id:RectID, selected: bool]
  FontTable = Table[float, wtypes.wFont]
  wBlockPanel = ref object of wSDLPanel
    mRectTable: RectTable
    mSurfaceCache: Table[CacheKey, SurfacePtr]
    mTextureCache: Table[CacheKey, TexturePtr]
    mFirmSelection: seq[RectID]
    mRatio: float
    mAllBbox: wRect
    mSelectBox: wRect
    mDstRect: wRect
    mText: string

  wMainPanel = ref object of wPanel
    mBlockPanel: wBlockPanel
    mRectTable: RectTable
    mSpnr: wSpinCtrl
    mTxt:  wStaticText
    mChk:  wCheckBox
    mBox1: wStaticBox
    mBox2: wStaticBox
    mCTRb1:     wRadioButton # Compact type radio button
    mCTRb2:     wRadioButton # Compact type radio button
    mCTRb3:     wRadioButton # Compact type radio button
    mAStratRb1: wRadioButton # Anneal strategy radio button
    mAStratRb2: wRadioButton # Anneal strategy radio button
    mAStratRb3: wRadioButton # Anneal strategy radio button
    mAStratRb4: wRadioButton # Anneal strategy radio button
    mSldr: wSlider
    mButtons: array[17, wButton]

  wMainFrame = ref object of wFrame
    mMainPanel: wMainPanel
    #mMenuBar:   wMenuBar # already defined by wNim
    mMenuFile:  wMenu
    #mStatusBar: wStatusBar # already defined by wNim

  Command = enum
    CmdEscape
    CmdMove
    CmdDelete
    CmdRotateCCW
    CmdRotateCW
    CmdSelect
    CmdSelectAll

  CmdKey = tuple[key: typeof(wKey_None), ctrl: bool, shift: bool, alt: bool]
  CmdTable = Table[CmdKey, Command]
  
  MouseState = enum
    StateNone
    StateLMBDownInRect
    StateLMBDownInSpace
    StateDraggingRect
    StateDraggingSelect

  MouseData = tuple
    clickHitIds: seq[RectID]
    dirtyIds:    seq[RectID]
    clickPos:    wPoint
    lastPos:     wPoint
    state:       MouseState


const 
  cmdTable: CmdTable = 
    {(key: wKey_Esc,    ctrl: false, shift: false, alt: false): CmdEscape,
     (key: wKey_Left,   ctrl: false, shift: false, alt: false): CmdMove,
     (key: wKey_Up,     ctrl: false, shift: false, alt: false): CmdMove,
     (key: wKey_Right,  ctrl: false, shift: false, alt: false): CmdMove,
     (key: wKey_Down,   ctrl: false, shift: false, alt: false): CmdMove,
     (key: wKey_Delete, ctrl: false, shift: false, alt: false): CmdDelete,
     (key: wKey_Space,  ctrl: false, shift: false, alt: false): CmdRotateCCW,
     (key: wKey_Space,  ctrl: false, shift: true,  alt: false): CmdRotateCW,
     (key: wKey_A,      ctrl: true,  shift: false, alt: false): CmdSelectAll }.toTable
  moveTable: array[wKey_Left .. wKey_Down, wPoint] =
    [(-1,0), (0, -1), (1, 0), (0, 1)]
  logRandomize = true

var 
  mouseData: MouseData
  fontPts: seq[float] = collect(for x in 6..24: x.float)
  fonts: FontTable = collect(
                       for sz in fontPts: 
                         (sz, Font(sz, wFontFamilyRoman))).toTable

template SDLRect(rect: rects.Rect|wRect): sdl2.Rect =
  # Not sure why I can't label the tuple elements with x:, y:, etc.
  (rect.x.cint, 
   rect.y.cint, 
   rect.width.cint,
   rect.height.cint)

template SDLPoint(pt: wPoint): sdl2.Point =
  #(pt.x.cint, pt.y.cint)
  (pt.x.cint, pt.y.cint)

proc excl[T](s: var seq[T], item: T) =
  # Not order preserving because it uses del
  # Use delete to preserve order
  while item in s:
    s.del(s.find(item))

template lParamTuple[T](event: wEvent): auto =
  (LOWORD(event.getlParam).T,
   HIWORD(event.getlParam).T)

proc fontSize(size: wSize): float =
  # Return font size based on rect size
  # round to int
  let px = min(size.width, size.height)
  let scale = 0.25
  let spix:float  = (px.float * scale).round.float
  let fp = fontPts[fontPts.low] .. fontPts[fontPts.high]
  clamp(spix, fp)


wClass(wBlockPanel of wSDLPanel):
  proc rectToTexture(self: wBlockPanel, rect: rects.Rect, sel: bool,
                     font: FontPtr): TexturePtr = 
    # Draw rect and label onto texture; return texture.
    let (w, h) = (rect.width, rect.height)
    let (ox, oy) = (rect.origin.x, rect.origin.y)
    let sdlRect = rect(0, 0, w, h)
    result = self.sdlRenderer.createTexture(SDL_PIXELFORMAT_RGBA8888,SDL_TEXTUREACCESS_TARGET,w,h)
    self.sdlRenderer.setRenderTarget(result)

    # Draw main filled rectangle with outline
    self.sdlRenderer.setDrawColor(SDLColor rect.brushcolor.rbswap)
    self.sdlRenderer.fillRect(addr sdlRect)
    self.sdlRenderer.setDrawColor(SDLColor rect.pencolor.rbswap)
    self.sdlRenderer.drawRect(addr sdlRect)
    self.sdlRenderer.setDrawColor(SDLColor wBlack.rbswap)
    self.sdlRenderer.drawLine(ox-10, oy, ox+10, oy)
    self.sdlRenderer.drawLine(ox, oy-10, ox, oy+10)

    # Render text to surface, create texture, then copy to output texture
    let selstr = $rect.id & (if sel: "*" else: "")
    let ts = font.renderUtf8Blended(selstr.cstring, SDLColor 0)
    let tt = self.sdlRenderer.createTextureFromSurface(ts)
    let dstRect: sdl2.Rect = ((w div 2) - (ts.w div 2),
                              (h div 2) - (ts.h div 2), ts.w, ts.h)
    self.sdlRenderer.copy(tt, nil, addr dstRect)

    # Return render target back to screen
    self.sdlRenderer.setRenderTarget(nil)

  proc rectToSurface(self: wBlockPanel, rect: rects.Rect, sel: bool,
                     font: FontPtr): SurfacePtr = 
    # Draw rect and label onto surface; return surface.
    let (w, h) = (rect.width, rect.height)
    let (ox, oy) = (rect.origin.x, rect.origin.y)
    let sdlRect = rect(0, 0, w, h)
    const 
      rmask = 0x000000ff'u32
      gmask = 0x0000ff00'u32
      bmask = 0x00ff0000'u32
      amask = 0xff000000'u32
    result = createRGBSurface(0, w, h, 32, rmask, gmask, bmask, amask)
    var renderer = createSoftwareRenderer(result)
    # Draw main filled rectangle with outline
    renderer.setDrawColor(SDLColor rect.brushcolor.rbswap)
    renderer.fillRect(addr sdlRect)
    renderer.setDrawColor(SDLColor rect.pencolor.rbswap)
    renderer.drawRect(addr sdlRect)
    renderer.setDrawColor(SDLColor wBlack.rbswap)
    renderer.drawLine(ox-10, oy, ox+10, oy)
    renderer.drawLine(ox, oy-10, ox, oy+10)
    renderer.destroy()

    # Render text to surface, create texture, then copy to output texture
    let selstr = $rect.id & (if sel: "*" else: "")
    let textSurface = font.renderUtf8Blended(selstr.cstring, SDLColor 0)
    let (tsw, tsh) = (textSurface.w, textSurface.h)
    let dstRect: sdl2.Rect = ((w div 2) - (tsw div 2),
                              (h div 2) - (tsh div 2), tsw, tsh)
    textSurface.blitSurface(nil, result, addr dstRect)
    textSurface.destroy()
    

  proc forceRedraw(self: wBlockPanel, wait: int = 0) = 
    self.refresh(false)
    UpdateWindow(self.mHwnd)
    if wait > 0: sleep(wait)

  proc initSurfaceCache(self: wBlockPanel) =
    # Creates all new surfaces
    for surface in self.mSurfaceCache.values:
      surface.destroy()
    self.mSurfaceCache.clear()
    let font = openFont("fonts/DejaVuSans.ttf", 20)
    for id, rect in self.mRectTable:
      for sel in [false, true]:
        self.mSurfaceCache[(id, sel)] = self.rectToSurface(rect, sel, font)

  proc initTextureCache(self: wBlockPanel) =
    # Copies surfaces from surfaceCache to textures
    for texture in self.mTextureCache.values:
      texture.destroy()
    self.mTextureCache.clear()
    for key, surface in self.mSurfaceCache:
      self.mTextureCache[key] = 
        self.sdlRenderer.createTextureFromSurface(surface)

  proc boundingBox(self: wBlockPanel) = 
    self.mAllBbox = boundingBox(self.mRectTable.values.toSeq)
  proc onResize(self: wBlockPanel, event: wEvent) =
    # Post user message so top frame can show new size
    self.initTextureCache() # Todo check whether new renderer onresize
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_SIZE, event.mWparam, event.mLparam)
  proc updateRatio(self: wBlockPanel) =
    let ratio = self.mRectTable.fillRatio
    if ratio != self.mRatio:
      echo ratio
      self.mText = $ratio
      self.mRatio = ratio
  proc moveRectsBy(self: wBlockPanel, rectIds: seq[RectId], delta: wPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    # Refer to comments as late as 27ff3c9a056c7b49ffe30d6560e1774091c0ae93
    let rects = self.mRectTable[rectIDs]
    for rect in rects:
      moveRectBy(rect, delta)
    self.mAllBbox = boundingBox(self.mRectTable.values.toSeq)
    self.updateRatio()
    self.refresh(false)
  proc moveRectBy(self: wBlockPanel, rectId: RectId, delta: wPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    moveRectBy(self.mRectTable[rectId], delta)
    self.mAllBbox = boundingBox(self.mRectTable.values.toSeq)
    self.updateRatio()
    self.refresh(false)
  proc deleteRects(self: wBlockPanel, rectIds: seq[RectId]) =
    for id in rectIds:
      self.mRectTable.del(id) # Todo: check whether this deletes rect
      for sel in [true, false]:
        self.mTextureCache[(id, sel)].destroy()
        self.mTextureCache.del((id, sel))
    self.mAllBbox = boundingBox(self.mRectTable.values.toSeq)
    self.updateRatio()
    self.refresh(false)
  proc rotateRects(self: wBlockPanel, rectIds: seq[RectId], amt: Rotation) =
    for id in rectIds:
      self.mRectTable[id].rotate(amt)
    self.mAllBbox = boundingBox(self.mRectTable.values.toSeq)
    self.updateRatio()
    self.refresh(false)
  proc selectAll(self: wBlockPanel) =
    discard setRectSelect(self.mRectTable)
    self.refresh()
  proc selectNone(self: wBlockPanel) =
    discard clearRectSelect(self.mRectTable)
    self.refresh()
  proc modifierText(event: wEvent): string = 
    if event.ctrlDown: result &= "Ctrl"
    if event.shiftDown: result &= "Shift"
    if event.altDown: result &= "Alt"
  proc isModifierEvent(event: wEvent): bool = 
    event.keyCode == wKey_Ctrl or
    event.keyCode == wKey_Shift or
    event.keyCode == wKey_Alt
  proc isModifierPresent(event: wEvent): bool = 
    event.ctrlDown or event.shiftDown or event.altDown
  proc processKeyDown(self: wBlockPanel, event: wEvent) =
    # event must not be a modifier key
    proc resetBox() =
      self.mSelectBox = (0,0,0,0)
      self.refresh(false)
    proc resetMouseData() = 
      mouseData.clickHitIds.setLen(0)
      mouseData.dirtyIds.setLen(0)
      mouseData.clickPos = (0,0)
      mouseData.lastPos = (0,0)
    proc escape() =
      resetMouseData()
      resetBox()
      if mouseData.state == StateDraggingSelect:
        let clrsel = (self.mRectTable.selected.toHashSet - self.mFirmSelection.toHashSet).toSeq
        discard self.mRectTable.clearRectSelect(clrsel)
        self.refresh(false)
      mouseData.state = StateNone

    # Stay only if we have a legitimate key combination
    let k = (event.keycode, event.ctrlDown, event.shiftDown, event.altDown)
    if not (k in cmdTable):
      escape()
      return

    let sel = self.mRectTable.selected
    case cmdTable[k]:
    of CmdEscape:
      escape()
    of CmdMove:
      self.moveRectsBy(sel, moveTable[event.keyCode])
      resetBox()
      mouseData.state = StateNone
    of CmdDelete:
      self.deleteRects(sel)
      resetBox()
      mouseData.state = StateNone
    of CmdRotateCCW:
      if mouseData.state == StateDraggingRect or 
         mouseData.state == StateLMBDownInRect:
        self.rotateRects(@[mouseData.clickHitIds[^1]], R90)
      else:
        self.rotateRects(sel, R90)
        resetBox()
        mouseData.state = StateNone
    of CmdRotateCW:
      if mouseData.state == StateDraggingRect or 
         mouseData.state == StateLMBDownInRect:
        self.rotateRects(@[mouseData.clickHitIds[^1]], R270)
      else:
        self.rotateRects(sel, R270)
        resetBox()
        mouseData.state = StateNone
    of CmdSelect:
      discard
    of CmdSelectAll:
      self.selectAll()
      self.mSelectBox = (0,0,0,0)
      mouseData.state = StateNone
  proc processUiEvent*(self: wBlockPanel, event: wEvent) = 
    # Unified event processing

    # We don't deal with modifier keys directly
    if isModifierEvent(event):
      return
    
    # Do all key processing first; all else is mouse state stuff
    if event.getEventType == wEvent_KeyDown:
      self.processKeyDown(event)
      return
    elif event.getEventType == wEvent_KeyUp:
      return

    # Send mouse message for x,y position
    if event.getEventType == wEvent_MouseMove:
      let hWnd = GetAncestor(self.handle, GA_ROOT)
      SendMessage(hWnd, USER_MOUSE_MOVE, event.mWparam, event.mLparam)

    case mouseData.state
    of StateNone:
      case event.getEventType
      of wEvent_LeftDown:
        SetFocus(self.mHwnd) # Selects region so it captures keyboard
        mouseData.clickPos = event.mousePos
        mouseData.lastPos  = event.mousePos
        mouseData.clickHitIds = self.mRectTable.ptInRects(event.mousePos)
        if mouseData.clickHitIds.len > 0: # Click in rect
          mouseData.dirtyIds = self.mRectTable.rectInRects(mouseData.clickHitIds[^1])
          mouseData.state = StateLMBDownInRect
        else: # Click in clear area
          mouseData.state = StateLMBDownInSpace
      else:
        # let ptir = self.mRectTable.ptInRects(event.mousePos)
        # if ptir.len > 0:
        #   echo ptir
        discard
    of StateLMBDownInRect:
      let hitid = mouseData.clickHitIds[^1]
      case event.getEventType
      of wEvent_MouseMove:
        mouseData.state = StateDraggingRect
      of wEvent_LeftUp:
        if event.mousePos == mouseData.clickPos: # click and release in rect
          var oldsel = self.mRectTable.selected
          if not event.ctrlDown: # clear existing except this one
            oldsel.excl(hitid)
            discard self.mRectTable.clearRectSelect(oldsel)
          self.mRectTable.toggleRectSelect(hitid) 
          mouseData.dirtyIds = oldsel & hitid
          self.refresh(false)
        mouseData.state = StateNone
      else:
        mouseData.state = StateNone
    of StateDraggingRect:
      let hitid = mouseData.clickHitIds[^1]
      let sel = self.mRectTable.selected
      case event.getEventType
      of wEvent_MouseMove:
        let delta = event.mousePos - mouseData.lastPos
        if event.ctrlDown and hitid in sel:
          self.moveRectsBy(sel, delta)
        else:
          self.moveRectBy(hitid, delta)
        mouseData.lastPos = event.mousePos
        self.refresh(false)
      else:
        mouseData.state = StateNone
    of StateLMBDownInSpace:
      case event.getEventType
      of wEvent_MouseMove:
        mouseData.state = StateDraggingSelect
        if event.ctrlDown:
          self.mFirmSelection = self.mRectTable.selected
        else:
          self.mFirmSelection.setLen(0)
      of wEvent_LeftUp:
        let oldsel = self.mRectTable.clearRectSelect()
        mouseData.dirtyIds = oldsel
        mouseData.state = StateNone
        self.refresh(false)
      else:
        mouseData.state = StateNone
    of StateDraggingSelect:
      case event.getEventType
      of wEvent_MouseMove:
        self.mSelectBox = normalizeRectCoords(mouseData.clickPos, event.mousePos)
        let newsel = self.mRectTable.rectInRects(self.mSelectBox)
        #let oldsel = self.mRectTable.clearRectSelect()
        discard self.mRectTable.setRectSelect(self.mFirmSelection)
        discard self.mRectTable.setRectSelect(newsel)
        self.refresh(false)
      of wEvent_LeftUp:
        self.mSelectBox = (0,0,0,0)
        mouseData.state = StateNone
        self.refresh(false)
      else:
        mouseData.state = StateNone

    self.mText.setLen(0)
    self.mText &= modifierText(event)
    self.mText &= &"State: {mouseData.state}"


# Todo: hovering over
# TODO optimize what gets invalidated during move

  #var angle: float = 0
  proc onPaint(self: wBlockPanel, event: wEvent) =
    let size = event.window.clientSize
    self.sdlRenderer.setDrawColor(SDLColor self.backgroundColor.rbswap)
    self.sdlRenderer.clear()
    self.sdlRenderer.setDrawBlendMode(BlendMode_Blend)
    

    # Blit all rectangles
    for drect in self.mRectTable.values:
      let texture = self.mTextureCache[(drect.id, drect.selected)]

      let dstrect = SDLRect drect.towRect(false)
      let angle = -drect.rot.toFloat
      let pt = SDLPoint drect.origin
      self.sdlRenderer.copyEx(texture, nil, addr dstrect, angle, addr pt)

    # Draw bounding box for everything
    let bbr = SDLRect self.mAllBbox
    self.sdlRenderer.setDrawColor(SDLColor wBlack.rbswap)
    self.sdlRenderer.drawRect(addr bbr)

    # Draw CmdSelection box directly to screen
    let selrect = SDLRect self.mSelectBox
    self.sdlRenderer.setDrawColor(0, 102, 204, 70)
    self.sdlRenderer.fillRect(addr selrect)
    self.sdlRenderer.setDrawColor(0, 120, 215)
    self.sdlRenderer.drawRect(addr selrect)

    # Draw destination box
    if self.mDstRect.width > 0:
      let dstrect = SDLRect self.mDstRect
      self.sdlRenderer.setDrawColor(SDLColor wRed.rbswap)
      self.sdlRenderer.drawRect(addr dstrect)

    self.sdlRenderer.present()

  # proc oldonPaint(self: wBlockPanel, event: wEvent) = 

  #   # draw current text, possibly sent from other thread
  #   let sw = self.mMemDc.charWidth * self.mText.len
  #   let ch = self.mMemDc.charHeight
  #   let textRect = (self.clientSize.width-sw, self.clientSize.height-ch, sw, ch)
  #   self.mMemDc.setBrush(Brush(wBlack))
  #   self.mMemDC.setTextBackground(self.backgroundColor)
  #   self.mMemDC.setFont(Font(pointSize=16, wFontFamilyRoman))
  #   self.mMemDC.drawLabel(self.mText, textRect, wMiddle)

  #   # Finally do last blit to main dc
  #   dc.blit(0, 0, dc.size.width, dc.size.height, self.mMemDc)
  #   mouseData.dirtyIds.setLen(0)
  #   SendMessage(self.mHwnd, USER_PAINT_DONE, 0, 0)
  #   release(gLock)
  
  proc onPaintDone(self: wBlockPanel) =
    discard

  proc init(self: wBlockPanel, parent: wWindow, rectTable: RectTable) = 
    wSDLPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
    self.mRectTable = rectTable
    self.mDstRect = (10, 10, 780, 780)

    self.wEvent_Size                 do (event: wEvent): flushEvents(0,uint32.high);self.onResize(event)
    self.wEvent_Paint                do (event: wEvent): flushEvents(0,uint32.high);self.onPaint(event)
    self.wEvent_MouseMove            do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_LeftDown             do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_LeftUp               do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_LeftDoubleClick      do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_MiddleDown           do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_MiddleUp             do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_MiddleDoubleClick    do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_RightDown            do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_RightUp              do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_RightDoubleClick     do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_MouseWheel           do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_MouseHorizontalWheel do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_KeyDown              do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_KeyUp                do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    #self.USER_PAINT_DONE             do (): self.onPaintDone()

wClass(wMainPanel of wPanel):
  proc layout(self: wMainPanel) =
    let bmarg = self.dpiScale(8)
    let (cszw, cszh) = self.clientSize
    let (bw, bh) = (self.dpiScale(150), self.dpiScale(30))
    let (lbpmarg, rbpmarg, tbpmarg, bbpmarg) = (0, 8, 0, 0)
    self.mBlockPanel.position = (bw + 2*bmarg + lbpmarg, tbpmarg)
    self.mBlockPanel.size = (cszw - bw - 2*bmarg - lbpmarg - rbpmarg, 
                             cszh - tbpmarg - bbpmarg)
    var yPosAcc = 0
    # Static text position, size
    self.mTxt.position = (bmarg, bmarg)
    self.mTxt.size = (bw div 2, self.mTxt.size.height)

    # Spin Ctrl position, size
    self.mSpnr.position = (bmarg + (bw div 2), bmarg)
    self.mSpnr.size     = (bw div 2, self.mSpnr.size.height)
    yPosAcc += bmarg + self.mTxt.size.height

    # Selection strategy pos, size
    self.mCTRb1.position = (bmarg,            yPosAcc); yPosAcc += bh
    self.mCTRb2.position = (bmarg,            yPosAcc)
    self.mCTRb3.position = (bmarg + bw div 2, yPosAcc)

    self.mCTRb1.size     = (bw,       bh)
    self.mCTRb2.size     = (bw div 2, bh)
    self.mCTRb3.size     = (bw div 2, bh)
    yPosAcc += bmarg + bh

    # Slider position, size
    self.mSldr.position = (bmarg, yPosAcc)
    self.mSldr.size    = (bw, bh)
    yPosAcc += bmarg + bh

    # Static box1 and radio button position, size
    self.mBox1.position      = (bmarg,   yPosAcc          )
    self.mAStratRb1.position = (bmarg*2, yPosAcc + bmarg*3); yPosAcc += self.mAStratRb1.size.height
    self.mAStratRb2.position = (bmarg*2, yPosAcc + bmarg*3); yPosAcc += self.mAStratRb2.size.height
    self.mBox1.size = (bw, self.mAStratRb1.size.height*2 + bmarg*4)
    yPosAcc += bmarg*5

    # Static box2 position, size
    self.mBox2.position = (bmarg,   yPosAcc          )
    self.mAStratRb3.position = (bmarg*2, yPosAcc + bmarg*3); yPosAcc += self.mAStratRb3.size.height
    self.mAStratRb4.position = (bmarg*2, yPosAcc + bmarg*3); yPosAcc += self.mAStratRb4.size.height
    self.mBox2.size = (bw, self.mAStratRb3.size.height*2 + bmarg*4)
    yPosAcc += bmarg*5

    # Buttons position, size
    for i, butt in self.mButtons:
      butt.position = (bmarg, yPosAcc)
      butt.size     = (bw, bh)
      yPosAcc += bh

  proc randomizeRectsAll(self: wMainPanel, qty: int) = 
    rectTable.randomizeRectsAll(self.mRectTable, self.mBlockPanel.clientSize, qty, logRandomize)
    self.mBlockPanel.initSurfaceCache()
    self.mBlockPanel.initTextureCache()

  proc delegate1DButtonCompact(self: wMainPanel, axis: Axis, sortOrder: SortOrder) = 
    #echo GC_getStatistics()
    withLock(gLock):
      compact(self.mRectTable, axis, sortOrder, self.mBlockPanel.mDstRect)
    self.mBlockPanel.boundingBox()
    self.mBlockPanel.updateRatio()
    self.refresh(false)
    GC_fullCollect()

  proc delegate2DButtonCompact(self: wMainPanel, direction: CompactDir) =
    # Leave if we have any threads already running
    if gCompactThread.running: return
    for i in gAnnealComms.low .. gAnnealComms.high:
      if gAnnealComms[i].thread.running: return

    let sz = self.mBlockPanel.clientSize
    let dstRect = self.mBlockPanel.mDstRect
    
    if self.mCtrb1.value: # Not anneal, just normal 2d compact
      let arg: CompactArg = (pRectTable: self.mRectTable.addr, 
                             direction:   direction,
                             window:      self,
                             dstRect:     dstRect)
      gCompactThread.createThread(compactWorker, arg)
      gCompactThread.joinThread()
      self.refresh(false)
    
    elif self.mCTRb2.value: # Do anneal
      proc compactfn() {.closure.} = 
        iterCompact(self.mRectTable, direction, dstRect)
      let strat = if self.mAStratRb1.value: Strat1
                  else:                     Strat2
      let perturbFn = if self.mAStratRb3.value: makeWiggler[PosTable, ptr RectTable](dstRect)
                      else:                     makeSwapper[PosTable, ptr RectTable]()
      for i in gAnnealComms.low .. gAnnealComms.high:
        let arg: AnnealArg = (pRectTable: self.mRectTable.addr,
                              strategy:   strat,
                              initTemp:   self.mSldr.value.float,
                              perturbFn:  perturbFn,
                              compactFn:  compactfn,
                              window:     self,
                              dstRect:    dstRect,
                              comm:       gAnnealComms[i])
        # Weird, TODO: just do once
        gAnnealComms[i].thread.createThread(annealMain, arg)
        break
    
    elif self.mCTRb3.value: # Do stack
      withLock(gLock):
        stackCompact(self.mRectTable, dstRect, direction)
      self.mBlockPanel.boundingBox()
      self.mBlockPanel.updateRatio()
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
  proc onStrategyRadioButton(self: wMainPanel, event: wEvent) =
    if self.mCTRb1.value: # No strategy
      self.mSldr.disable()
      self.mAStratRb1.disable()
      self.mAStratRb2.disable()
      self.mAStratRb3.disable()
      self.mAStratRb4.disable()
    elif self.mCTRb2.value: # Anneal strategy
      self.mSldr.enable()
      self.mAStratRb1.enable()
      self.mAStratRb2.enable()
      self.mAStratRb3.enable()
      self.mAStratRb4.enable()
    elif self.mCTRb3.value: # Stack strategy
      self.mSldr.disable()
      self.mAStratRb1.disable()
      self.mAStratRb2.disable()
      self.mAStratRb3.disable()
      self.mAStratRb4.disable()

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
    rectTable.randomizeRectsPos(self.mRectTable, sz)
    self.mBlockPanel.boundingBox()
    self.mBlockPanel.updateRatio()
    self.refresh(false)
  proc onButtonTest(self: wMainPanel) =
    for rect in self.mRectTable.values:
      echo &"id: {rect.id}, pos: {(rect.x, rect.y)}, size: {(rect.width, rect.height)}, rot: {rect.rot}"
  # Left  arrow = stack to the left,   which is x ascending
  # Right arrow = stack to the right,  which is x descending
  # Up    arrow = stack to the top,    which is y ascending
  # Down  arrow = stack to the bottom, which is y descending
  proc onButtonCompact←(self: wMainPanel) =
    self.delegate1DButtonCompact(X, Ascending)
  proc onButtonCompact→(self: wMainPanel) =
    self.delegate1DButtonCompact(X, Descending)
  proc onButtonCompact↑(self: wMainPanel) =
    self.delegate1DButtonCompact(Y, Ascending)
  proc onButtonCompact↓(self: wMainPanel) =
    self.delegate1DButtonCompact(Y, Descending)
  proc onButtonCompact←↑(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, Ascending, Ascending))
  proc onButtonCompact←↓(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, Ascending, Descending))
  proc onButtonCompact→↑(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, Descending, Ascending))
  proc onButtonCompact→↓(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, Descending, Descending))
  proc onButtonCompact↑←(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, Ascending, Ascending))
  proc onButtonCompact↑→(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, Ascending, Descending))
  proc onButtonCompact↓←(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, Descending, Ascending))
  proc onButtonCompact↓→(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, Descending, Descending))
  var ackCnt: int
  proc onAlgUpdate(self: wMainPanel, event: wEvent) =
    let (idx, _) = lParamTuple[int](event)
    let (msgAvail, msg) = gAnnealComms[idx].sendChan.tryRecv()
    if msgAvail:
        self.mBlockPanel.mText = $idx & ": " & msg 
    
    let (idAvail, ids) = gAnnealComms[idx].idChan.tryRecv()
    withLock(gLock):
      self.mBlockPanel.boundingBox()
      self.mBlockPanel.forceRedraw(0)
      gAnnealComms[idx].ackChan.send(ackCnt)
    inc ackCnt

  proc init(self: wMainPanel, parent: wWindow, rectTable: RectTable, initialRectQty: int) =
    wPanel(self).init(parent)

    # Create controls
    self.mSpnr      = SpinCtrl(self, id=wCommandID(1), value=initialRectQty, style=wAlignRight)
    self.mTxt       = StaticText(self, label="Qty", style=wSpRight)
    self.mBox1      = StaticBox(self, label="Anneal Strategy")
    self.mBox2      = StaticBox(self, label="Anneal Perturb Func")
    self.mCTRb1     = RadioButton(self, label="None", style=wRbGroup)
    self.mCTRb2     = RadioButton(self, label="Anneal")
    self.mCTRb3     = RadioButton(self, label="Stack" )
    self.mAStratRb1 = RadioButton(self, label="Strat1", style=wRbGroup)
    self.mAStratRb2 = RadioButton(self, label="Strat2")
    self.mAStratRb3 = RadioButton(self, label="Wiggle", style=wRbGroup)
    self.mAStratRb4 = RadioButton(self, label="Swap"  )

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

    # Connect events
    self.wEvent_Size                    do (event: wEvent): self.onResize()
    self.mSpnr.wEvent_Spin              do (event: wEvent): self.onSpinSpin(event)
    self.mSpnr.wEvent_TextEnter         do (): self.onSpinTextEnter()
    self.mCTRb1.wEvent_RadioButton      do (event: wEvent): self.onStrategyRadioButton(event)
    self.mCTRb2.wEvent_RadioButton      do (event: wEvent): self.onStrategyRadioButton(event)
    self.mCTRb3.wEvent_RadioButton      do (event: wEvent): self.onStrategyRadioButton(event)
    self.mSldr.wEvent_Slider            do (event: wEvent): self.onSlider(event)
    self.mButtons[ 0].wEvent_Button     do (): self.onButtonrandomizeAll()
    self.mButtons[ 1].wEvent_Button     do (): self.onButtonrandomizePos()
    self.mButtons[ 2].wEvent_Button     do (): self.onButtonTest()
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

    # Set up stuff
    self.mRectTable = rectTable
    self.mBlockPanel = BlockPanel(self, rectTable)
    self.mSpnr.setRange(1, 10000)
    self.mSldr.setValue(20)
    self.mCTRb1.click()
    self.mAStratRb1.click()
    self.mAStratRb3.click()

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
    self.mStatusBar.setStatusWidths([-2, -1, 200])
    
    # A couple of cheats because I'm not sure how to do these when the mBlockPanel is 
    # finally rendered at the proper size
    self.mStatusBar.setStatusText($newBlockSz, index=1)
    let sldrVal = self.mMainPanel.mSldr.value
    let tmpStr = &"temperature: {sldrVal}"
    self.mStatusBar.setStatusText(tmpStr, index=0)
    rectTable.randomizeRectsAll(newBlockSz, self.mMainPanel.mSpnr.value, logRandomize)
    self.mMainPanel.mBlockPanel.initSurfaceCache()
    self.mMainPanel.mBlockPanel.initTextureCache()
    self.mMainPanel.mBlockPanel.mAllBbox = boundingBox(self.mMainPanel.mRectTable.values.toSeq)

    # Connect Events
    self.wEvent_Size     do (event: wEvent): self.onResize(event)
    self.USER_SIZE       do (event: wEvent): self.onUserSizeNotify(event)
    self.USER_MOUSE_MOVE do (event: wEvent): self.onUserMouseNotify(event)
    self.USER_SLIDER     do (event: wEvent): self.onUserSliderNotify(event)

    # Show!
    self.center()
    self.show()
    self.mMainPanel.mBlockPanel.forceRedraw()
    self.mMainPanel.mBlockPanel.forceRedraw()

  

