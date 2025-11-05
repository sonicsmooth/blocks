import std/[math, segfaults, sets, sugar, strformat, tables ]
from std/sequtils import toSeq
import wNim
import winim except PRECT, Color
import sdl2
import rects, recttable, sdlframes, db, viewport, grid, pointmath
import userMessages, utils, appopts
import render

# TODO: update qty when spinner text loses focus
# TODO: Load up system colors from HKEY_CURRENT_USER\Control Panel\Colors

type
  MouseState = enum
    StateNone
    StateLMBDownInRect
    StateLMBDownInSpace
    StateDraggingRect
    StateDraggingSelect
  PanZoomState = enum
    PZStateNone
    PZStateRMBDown
    PZStateRMBMoving
  MouseData = tuple
    clickHitIds: seq[CompID]
    dirtyIds:    seq[CompID]
    clickPos:    wPoint # comes from winim (wPoint) not SDL2 (cint)
    lastPos:     wPoint # comes from winim (wPoint) not SDL2 (cint)
    state:       MouseState
    pzState:     PanZoomState
  CacheKey = tuple[id:CompID, selected, hovering: bool]
  wBlockPanel* = ref object of wSDLPanel
    mMouseData: MouseData
    mTextureCache: Table[CacheKey, TexturePtr]
    mFirmSelection*: seq[CompID]
    mFillArea*: WType
    mRatio*: float
    mAllBbox*: WRect
    mDstRect*: WRect
    mSelectBox*: PRect
    mText*: string
    mGrid*: Grid
    mViewport*: Viewport
 
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
  

const 
  cmdTable: CmdTable = 
    {(key: wKey_Esc,    ctrl: false, shift: false, alt: false): CmdEscape,
     (key: wKey_Left,   ctrl: false, shift: false, alt: false): CmdMove,
     (key: wKey_Up,     ctrl: false, shift: false, alt: false): CmdMove,
     (key: wKey_Right,  ctrl: false, shift: false, alt: false): CmdMove,
     (key: wKey_Down,   ctrl: false, shift: false, alt: false): CmdMove,
     (key: wKey_Left,   ctrl: false, shift: true,  alt: false): CmdMove,
     (key: wKey_Up,     ctrl: false, shift: true,  alt: false): CmdMove,
     (key: wKey_Right,  ctrl: false, shift: true,  alt: false): CmdMove,
     (key: wKey_Down,   ctrl: false, shift: true,  alt: false): CmdMove,
     (key: wKey_Delete, ctrl: false, shift: false, alt: false): CmdDelete,
     (key: wKey_Space,  ctrl: false, shift: false, alt: false): CmdRotateCCW,
     (key: wKey_Space,  ctrl: false, shift: true,  alt: false): CmdRotateCW,
     (key: wKey_A,      ctrl: true,  shift: false, alt: false): CmdSelectAll }.toTable
  moveTable: array[wKey_Left .. wKey_Down, WPoint] =
    [(-1,0), (0, 1), (1, 0), (0, -1)]



wClass(wBlockPanel of wSDLPanel):
  proc forceRedraw*(self: wBlockPanel, wait: int = 0) = 
    self.refresh(false)
    UpdateWindow(self.mHwnd)

  proc clearTextureCache*(self: wBlockPanel) =
    # Clear all textures
    for texture in self.mTextureCache.values:
      texture.destroy()
    self.mTextureCache.clear()

  proc clearTextureCache*(self: wBlockPanel, id: CompID) =
    # Clear specific id from texture cache
    for sel in [false, true]:
      for hov in [false, true]:
        let key = (id, sel, hov)
        if key in self.mTextureCache:
          self.mTextureCache[key].destroy()
        self.mTextureCache.del(key)

  proc clampRectSize(self: wBlockPanel, prect: PRect): PRect =
    # Return the given prect if one or more dimensions fits in client area
    # If both dimensions exceed client size, then return a PRect with the
    # same aspect ratio and with one dim that matches client dim.
    if prect.w <= self.size.width or prect.h <= self.size.height:
      prect
    else:
      let 
        rectRatio: float = prect.w.float / prect.h.float
        clientRatio: float = self.size.width / self.size.height
      var neww, newh: int
      if rectRatio <= clientRatio:
        # Set rect width to client width
        neww = self.size.width
        newh = (neww.float / rectRatio).round.int
      else:
        # Set rect height to client height
        newh = self.size.height
        neww = (newh.float * rectRatio).round.int
      (x: prect.x, y: prect.y, w: neww, h: newh)
        

  proc getFromTextureCache(self: wBlockPanel, id: CompID): TexturePtr =
    # Returns block texture, using cache if possible.
    #  Uses software renderer to draw to newly created surface,
    #  then creates texture from surface
    # Returns nil if any block dimension is zero
    # Throws exception if surface or texture can't be created.
    let 
      rect = gDb[id]
      key = (id, rect.selected, rect.hovering)
      vp = self.mViewport
    if self.mTextureCache.hasKey(key):
      self.mTextureCache[key]
    else:
      let 
        prect = rect.bbox.toPRect(vp)
        cprect = self.clampRectSize(prect)
      if cprect.w == 0 or cprect.h == 0:
        # We are zoomed out too far
        return nil
      let
        surface = createRGBSurface(0, cprect.w, cprect.h, 32, rmask, gmask, bmask, amask)
        swRenderer = createSoftwareRenderer(surface)
      swRenderer.renderDBComp(vp, rect, cprect, zero=true)
      let pTexture = self.sdlRenderer.createTextureFromSurface(surface)
      if pTexture.isNil:
        raise newException(ValueError, &"Texture pointer is nil from createTextureFromSurface: {getError()}")
      self.mTextureCache[key] = pTexture
      pTexture
  
  proc blitFromTextureCache(self: wBlockPanel) =
    # Copy from texture cache to screen via sdlrenderer
    let
      vp = self.mViewport
      sz: PxSize = self.size
      screenRect: WRect = (0.PxType, 0.PxType, sz.w, sz.h).toWrect(vp)
    var dstRect: PRect
    componentsVisible.setLen(0)
    for rect in gDb.values:
      if isRectSeparate(rect.bbox, screenRect):
        continue
      let pTexture: TexturePtr = self.getFromTextureCache(rect.id)
      if not pTexture.isNil:
        componentsVisible.add(rect)
        dstRect = rect.bbox.toPRect(vp)
        self.sdlRenderer.copy(pTexture, nil, addr dstRect)
  
  proc renderToScreen(self: wBlockPanel) =
    # Render blocks to screen using default renderer
    let
      vp = self.mViewport
      sz: PxSize = self.size
      screenRect: WRect = (0.PxType, 0.PxType, sz.w, sz.h).toWrect(vp)
    for rect in gDb.values:
      if isRectSeparate(rect.bbox, screenRect):
        continue
      let
        prect = rect.bbox.toPRect(vp)
        cprect = self.clampRectSize(prect)
      self.sdlRenderer.renderDBComp(vp, rect, cprect, zero=false)

  proc updateDestinationBox(self: wBlockPanel) =
    let 
      marg = 25
      (w, h) = self.size
    let pdstrect: PRect = (marg, marg, w - 2*marg, h - 2*marg)
    self.mDstRect = pdstrect.toWRect(self.mViewport)

  proc updateBoundingBox(self: wBlockPanel) =
    self.mAllBbox = gDb.boundingBox()

  # proc onResize(self: wBlockPanel, event: wEvent) =
  #   # Post user message so top frame can show new size
  #   discard
  #   let hWnd = GetAncestor(self.handle, GA_ROOT)
  #   SendMessage(hWnd, idMsgSize, event.mWparam, event.mLparam)

  proc updateRatio*(self: wBlockPanel) =
    if gDb.len == 0:
      self.mRatio = 0.0
    else:
      let ratio = self.mFillArea.float / self.mAllBbox.area.float
      if ratio != self.mRatio:
        self.mRatio = ratio
  proc moveRectsBy(self: wBlockPanel, compIDs: seq[CompID], delta: WPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    # Refer to comments as late as 27ff3c9a056c7b49ffe30d6560e1774091c0ae93
    let rects = gDb[compIDs]
    for rect in rects:
      moveRectBy(rect, delta)
    self.refresh(false)
  proc moveRectBy(self: wBlockPanel, compID: CompID, delta: WPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    moveRectBy(gDb[compID], delta)
    self.refresh(false)
  proc moveRectTo(self: wBlockPanel, compID: CompID, delta: WPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    moveRectTo(gDb[compID], delta)
    self.refresh(false)
  proc rotateRects(self: wBlockPanel, compIDs: seq[CompID], amt: Rotation) =
    for id in compIDs:
      gDb[id].rotate(amt)
      self.clearTextureCache(id)
    self.refresh(false)
  proc deleteRects(self: wBlockPanel, compIDs: seq[CompID]) =
    for id in compIDs:
      gDb.del(id) # Todo: check whether this deletes rect
      self.clearTextureCache(id)
    self.mFillArea = gDb.fillArea()
    self.refresh(false)
  proc selectAll(self: wBlockPanel) =
    gDb.setRectSelect()
    self.refresh()
  proc selectNone(self: wBlockPanel) =
    gDb.clearRectSelect()
    self.refresh()
  proc isModifierEvent(event: wEvent): bool = 
    event.keyCode == wKey_Ctrl or
    event.keyCode == wKey_Shift or
    event.keyCode == wKey_Alt
  proc evaluateHovering(self: wBlockPanel, event: wEvent): bool {.discardable.} =
    # clear and set hovering
    # Return true if something changed
    if gAppOpts.enableHover:
      let
        cleared = gDb.clearRectHovering()
        newset = gDb.setRectHovering(gDb.ptInRects(event.mousePos, self.mViewport))
      len(cleared) > 0 or len(newset) > 0
    else:
      false
  proc processKeyDown(self: wBlockPanel, event: wEvent) =
    # event must not be a modifier key
    proc resetBox() =
      self.mSelectBox = (0,0,0,0)
      self.refresh(false)
    proc resetMouseData() = 
      self.mMouseData.clickHitIds.setLen(0)
      self.mMouseData.dirtyIds.setLen(0)
      self.mMouseData.clickPos = (0, 0)
      self.mMouseData.lastPos = (0, 0)
    proc escape() =
      resetMouseData()
      resetBox()
      if self.mMouseData.state == StateDraggingSelect:
        let clrsel = (gDb.selected.toHashSet - self.mFirmSelection.toHashSet).toSeq
        gDb.clearRectSelect(clrsel)
        self.refresh(false)
      self.mMouseData.state = StateNone

    # Stay only if we have a legitimate key combination
    let k = (event.keycode, event.ctrlDown, event.shiftDown, event.altDown)
    if not (k in cmdTable):
      escape()
      return

    let sel = gDb.selected()
    case cmdTable[k]:
    of CmdEscape:
      escape()
    of CmdMove:
      let
        md: WPoint = 
          if event.shiftDown:
            minDelta(self.mGrid, scale=Tiny)
          else:
            minDelta(self.mGrid, scale=Minor)
        moveby: WPoint = md .* moveTable[event.keyCode]
      self.moveRectsBy(sel, moveBy)
      resetBox()
      self.mMouseData.state = StateNone
    of CmdDelete:
      self.deleteRects(sel)
      resetBox()
      self.mMouseData.state = StateNone
    of CmdRotateCCW:
      if self.mMouseData.state == StateDraggingRect or 
         self.mMouseData.state == StateLMBDownInRect:
        self.rotateRects(@[self.mMouseData.clickHitIds[^1]], R90)
        self.evaluateHovering(event)
        self.refresh(false)
      else:
        self.rotateRects(sel, R90)
        self.evaluateHovering(event)
        resetBox()
        self.refresh(false)
        self.mMouseData.state = StateNone
    of CmdRotateCW:
      if self.mMouseData.state == StateDraggingRect or 
         self.mMouseData.state == StateLMBDownInRect:
        self.rotateRects(@[self.mMouseData.clickHitIds[^1]], R270)
        self.evaluateHovering(event)
        self.refresh(false)
      else:
        self.rotateRects(sel, R270)
        self.evaluateHovering(event)
        resetBox()
        self.refresh(false)
        self.mMouseData.state = StateNone
    of CmdSelect:
      discard
    of CmdSelectAll:
      self.selectAll()
      self.mSelectBox = (0,0,0,0)
      self.mMouseData.state = StateNone

  proc processUiEvent*(self: wBlockPanel, event: wEvent) = 
    # Unified event processing
    # Separate specific events (eg shft+LMB) from state changes
    # For example, StateLMBDownInRect should be renamed to
    # something like StateSelectStartInRect, and the event
    # that gets into that state is MainSelector which comes 
    # from mouseEvent == wEvent_LeftDown.
    # so wEvent_LeftDown is mapped to MainSelector, which triggers
    # state change from None to StateSelectStartInRect
    # Also dragging is delayed by one event; fix it.

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
    if event.eventType == wEvent_MouseMove or
       event.eventType == wEvent_MouseWheel:
      let hWnd = GetAncestor(self.handle, GA_ROOT)
      SendMessage(hWnd, idMsgMouseMove, event.wParam, event.lParam)

    let 
      vp = self.mViewport
      wmp = event.mousePos.toWorld(vp)
    
    case self.mMouseData.pzState:
    of PZStateNone:
      case event.getEventType
      of wEvent_RightDown:
        self.mMouseData.clickPos = event.mousePos
        self.mMouseData.lastPos  = event.mousePos
        self.mMouseData.pzState = PZStateRMBDown
      of wEvent_RightUp:
        self.mMouseData.pzState = PZStateNone
      of wEvent_MouseWheel:
        # Keep mouse location in the same spot during zoom.
        doAdaptivePanZoom(self.mViewport, event.wheelRotation, event.mousePos)
        self.clearTextureCache()
        self.refresh(false)
      else:
        discard
    of PZStateRMBDown:
      case event.getEventType
      of wEvent_MouseMove:
        let deltaPx: PxPoint = event.mousePos - self.mMouseData.lastPos
        self.mMouseData.lastPos = event.mousePos
        self.mViewport.doPan(deltaPx)
        self.refresh(false)
      of wEvent_RightUp:
        self.mMouseData.pzState = PZStateNone
      else:
        discard
    else:
      discard

    case self.mMouseData.state
    of StateNone:
      case event.getEventType
      of wEvent_MouseMove:
        if self.mMouseData.pzState == PZStateNone:
          if self.evaluateHovering(event):
            self.refresh(false)
        else:
          discard
      of wEvent_LeftDown:
        SetFocus(self.mHwnd) # Selects region so it captures keyboard
        self.mMouseData.clickPos = event.mousePos
        self.mMouseData.lastPos  = event.mousePos
        self.mMouseData.clickHitIds = gDb.ptInRects(wmp)
        if self.mMouseData.clickHitIds.len > 0: # Click in rect
          self.mMouseData.dirtyIds = gDb.rectInRects(self.mMouseData.clickHitIds[^1])
          self.mMouseData.state = StateLMBDownInRect
        else: # Click in clear area
          self.mMouseData.state = StateLMBDownInSpace
      else:
        discard
    of StateLMBDownInRect:
      let hitid = self.mMouseData.clickHitIds[^1]
      case event.getEventType
      of wEvent_MouseMove:
        self.mMouseData.state = StateDraggingRect
      of wEvent_LeftUp:
        if event.mousePos == self.mMouseData.clickPos: # click and release in rect
          var oldsel = gDb.selected()
          if not event.ctrlDown: # clear existing except this one
            oldsel.excl(hitid)
            gDb.clearRectSelect(oldsel)
          gDb.toggleRectSelect(hitid) 
          self.mMouseData.dirtyIds = oldsel & hitid
          self.refresh(false)
        self.mMouseData.state = StateNone
      else:
        self.mMouseData.state = StateNone
    of StateDraggingRect:
      let hitid = self.mMouseData.clickHitIds[^1]
      let sel = gdb.selected()
      case event.getEventType
      of wEvent_MouseMove:
        # TODO: maybe implement shift-move to snap to Tiny
        let 
          scale = if self.mGrid.mSnap: Minor else: None
          lastSnap: WPoint = self.mMouseData.lastPos.toWorld(vp).snap(self.mGrid, scale=scale)
          newSnap: WPoint = wmp.snap(self.mGrid, scale=scale)
          delta: WPoint = newSnap - lastSnap
        if event.ctrlDown and hitid in sel:
          # Group move should snap by grid amount even if not on grid to start
          self.moveRectsBy(sel, delta)
          # Todo: make snap-to-grid proc like this
          # for id in sel:
          #   let newPos = self.mGrid.mSnap(gDb[id].pos + delta)
          #   self.moveRectTo(id, newPos)
        else: # Snap pos to nearest grid point
          let newPos = (gDb[hitid].pos + delta).snap(self.mGrid, scale=scale)
          self.moveRectTo(hitid, newPos)
        self.mMouseData.lastPos = event.mousePos
        self.refresh(false)
      else:
        self.mMouseData.state = StateNone
    of StateLMBDownInSpace:
      case event.getEventType
      of wEvent_MouseMove:
        self.mMouseData.state = StateDraggingSelect
        if event.ctrlDown:
          self.mFirmSelection = gDb.selected()
        else:
          self.mFirmSelection.setLen(0)
          gDb.clearRectSelect()
      of wEvent_LeftUp:
        let oldsel = gDb.clearRectSelect()
        self.mMouseData.dirtyIds = oldsel
        self.mMouseData.state = StateNone
        self.refresh(false)
      else:
        self.mMouseData.state = StateNone
    of StateDraggingSelect:
      case event.getEventType
      of wEvent_MouseMove:
        let pbox: PRect = normalizePRectCoords(self.mMouseData.clickPos, event.mousePos)
        self.mSelectBox = pbox
        let newsel = gDb.rectInRects(self.mSelectBox, vp)
        gDb.clearRectSelect()
        gDb.setRectSelect(self.mFirmSelection)
        gDb.setRectSelect(newsel)
        self.refresh(false)
      of wEvent_LeftUp:
        self.mSelectBox = (0,0,0,0)
        self.mMouseData.state = StateNone
        self.refresh(false)
      else:
        self.mMouseData.state = StateNone


#[
Rendering options for pure SDL
1. Blitting to window renderer from sdl Texture cache
2. Rendering in real time directly to sdl surface

Rendering options for SDL and pixie
1. Blitting to window renderer...
  A. ...from sdl Texture cache (copied from pixie image cache on init and resize)
  C. ...from pixie image cache
2. Rendering in real time  
  B. Render to pixie image then blit to sdl surface


]# 

  proc onPaint(self: wBlockPanel, event: wEvent) =
    self.sdlRenderer.setDrawColor(self.backgroundColor.toColor)
    self.sdlRenderer.clear()
    
    # Draw grid
    self.mGrid.draw(self.mViewport, self.sdlRenderer, self.size)

    # Try a few methods to draw rectangles
    when defined(noTextureCache):
      self.renderToScreen()
    else:
      self.blitFromTextureCache()

    # Draw various boxes and text, then done
    self.updateDestinationBox()
    if gAppOpts.enableDstRect:
      self.sdlRenderer.renderOutlineRect(self.mDstRect.toPRect(self.mViewport), DarkOrchid)
    if gAppOpts.enableBbox:
      self.updateBoundingBox()
      self.sdlRenderer.renderOutlineRect(self.mAllBbox.toPRect(self.mViewport).grow(1), Green)
    self.sdlRenderer.renderFilledRect(self.mSelectBox,
                                      fillColor=(r:0, g:102, b:204, a:70).RGBATuple.toColorU32,
                                      penColor=(r:0, g:120, b:215, a:255).RGBATuple.toColorU32)
    var txt: string
    txt &= &"pan: {self.mViewport.pan}\n"
    txt &= &"zClicks: {self.mViewport.zClicks}\n"
    txt &= &"level: {self.mViewport.zCtrl.logStep}\n"
    txt &= &"rawZoom: {self.mViewport.rawZoom:.3f}\n"
    txt &= &"zoom: {self.mViewport.zoom:.3f}\n"
    txt &= &"smoothDelta: {minDelta(self.mGrid, scale=None)}\n"
    txt &= &"tinyDelta: {minDelta(self.mGrid, scale=Tiny)}\n"
    txt &= &"minorDelta: {minDelta(self.mGrid, scale=Minor)}\n"
    let majdelt = minDelta(self.mGrid, scale=Major)
    let pxwidth = (majdelt.x.float * self.mViewport.zoom).round.int
    txt &= &"majorDelta: {majdelt}\n"
    txt &= &"majorPx: {pxwidth}"
    
    self.sdlRenderer.renderText(self.sdlWindow, txt)
    self.sdlRenderer.present()

    # release(gLock)
  
  proc init*(self: wBlockPanel, parent: wWindow) = 
    discard
    wSDLPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
    let zc = newZoomCtrl(base=5, clickDiv=2400, maxPwr=5, density=1.0, dynamic=true, baseSync=true)
    self.mGrid = newGrid(zCtrl=zc)
    self.mViewport = newViewport(pan=(400,400), clicks=0, zCtrl=zc)

    #self.wEvent_Size                 do (event: wEvent): flushEvents(0,uint32.high);self.onResize(event)
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

    