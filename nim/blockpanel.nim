import std/[bitops, math, segfaults, sets, sugar, strformat, tables ]
from std/sequtils import toSeq
import timeit
import wNim
import winim except PRECT, Color
import sdl2
import rects, recttable, sdlframes, db, viewport, grid, pointmath
import userMessages, utils
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
    mViewPort*: ViewPort
 
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
    # Copies surfaces from surfaceCache to textures
    # Requires to be called when resize because of new texture
    let 
      rect = gDb[id]
      key = (id, rect.selected, rect.hovering)
      vp = self.mViewPort
    if self.mTextureCache.hasKey(key):
      self.mTextureCache[key]
    else:
      let 
        prect = rect.bbox.toPRect(vp)
        cprect = self.clampRectSize(prect)
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
      vp = self.mViewPort
      sz: PxSize = self.size
      screenRect: WRect = (0.PxType, 0.PxType, sz.w, sz.h).toWrect(vp)
    var dstRect: PRect
    componentsVisible.setLen(0)
    for rect in gDb.values:
      if isRectSeparate(rect.bbox, screenRect):
        continue
      componentsVisible.add(rect)
      let pTexture: TexturePtr = self.getFromTextureCache(rect.id)
      if pTexture.isNil:
        raise newException(ValueError, &"Texture pointer is nil from getFromTextureCache: {getError()}")
      dstRect = rect.bbox.toPRect(vp)
      self.sdlRenderer.copy(pTexture, nil, addr dstRect)
  
  proc renderToScreen(self: wBlockPanel) =
    # Render blocks to screen using default renderer
    let
      vp = self.mViewPort
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
    self.mDstRect = pdstrect.toWRect(self.mViewPort)

  proc onResize(self: wBlockPanel, event: wEvent) =
    # Post user message so top frame can show new size
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_SIZE, event.mWparam, event.mLparam)

  proc updateRatio*(self: wBlockPanel) =
    if gDb.len == 0:
      self.mRatio = 0.0
    else:
      self.mAllBbox = gDb.boundingBox()
      let ratio = self.mFillArea.float / self.mAllBbox.area.float
      if ratio != self.mRatio:
        self.mRatio = ratio
  proc moveRectsBy(self: wBlockPanel, CompIDs: seq[CompID], delta: WPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    # Refer to comments as late as 27ff3c9a056c7b49ffe30d6560e1774091c0ae93
    let rects = gDb[CompIDs]
    for rect in rects:
      moveRectBy(rect, delta)
    self.updateRatio()
    self.refresh(false)
  proc moveRectBy(self: wBlockPanel, CompID: CompID, delta: WPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    #let wdelta: WPoint = delta.toWorld(self.mViewPort)
    moveRectBy(gDb[CompID], delta)
    self.updateRatio()
    self.refresh(false)
  proc moveRectTo(self: wBlockPanel, CompID: CompID, delta: WPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    #let wdelta: WPoint = delta.toWorld(self.mViewPort)
    moveRectTo(gDb[CompID], delta)
    self.updateRatio()
    self.refresh(false)
  proc rotateRects(self: wBlockPanel, CompIDs: seq[CompID], amt: Rotation) =
    for id in CompIDs:
      gDb[id].rotate(amt)
      self.clearTextureCache(id)
    self.updateRatio()
    self.refresh(false)
  proc deleteRects(self: wBlockPanel, CompIDs: seq[CompID]) =
    for id in CompIDs:
      gDb.del(id) # Todo: check whether this deletes rect
      self.clearTextureCache(id)
    self.mFillArea = gDb.fillArea()
    self.updateRatio()
    self.refresh(false)
  proc selectAll(self: wBlockPanel) =
    gDb.setRectSelect()
    self.refresh()
  proc selectNone(self: wBlockPanel) =
    gDb.clearRectSelect()
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
  proc evaluateHovering(self: wBlockPanel, event: wEvent): bool {.discardable.} =
    # clear and set hovering
    # Return true if something changed
    let cleared = gDb.clearRectHovering()
    let newset = gDb.setRectHovering(gDb.ptInRects(event.mousePos, self.mViewPort))
    len(cleared) > 0 or len(newset) > 0
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
        md: WPoint = minDelta[WType](self.mGrid, self.mViewPort)
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
      #displayParams(event.wParam, event.lParam)
      let hWnd = GetAncestor(self.handle, GA_ROOT)
      SendMessage(hWnd, USER_MOUSE_MOVE, event.mWparam, event.lParam)


    let 
      vp = self.mViewPort
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
        let oldvp = self.mViewPort
        self.mViewPort.doZoom(event.wheelRotation)
        #let pxDelta = doAdaptivePan(oldvp, self.mViewPort, event.mousePos)
        #self.mViewPort.doPan(pxDelta)
        self.clearTextureCache()
        self.refresh(false)
      else:
        discard
    of PZStateRMBDown:
      case event.getEventType
      of wEvent_MouseMove:
        let deltaPx: PxPoint = event.mousePos - self.mMouseData.lastPos
        self.mMouseData.lastPos = event.mousePos
        self.mViewPort.doPan(deltaPx)
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
      # of wEvent_MouseMove:
      #   if self.mMouseData.pzState == PZStateNone:
      #     if self.evaluateHovering(event):
      #       self.refresh(false)
      #   else:
      #     discard
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
        let 
          lastSnap: WPoint = self.mMouseData.lastPos.toWorld(vp).snap(self.mGrid, vp)
          newSnap: WPoint = wmp.snap(self.mGrid, vp)
          delta: WPoint = newSnap - lastSnap
        if event.ctrlDown and hitid in sel:
          # Group move should snap by grid amount even if not on grid to start
          self.moveRectsBy(sel, delta)
          # Todo: make snap-to-grid proc like this
          # for id in sel:
          #   let newPos = self.mGrid.snap(gDb[id].pos + delta)
          #   self.moveRectTo(id, newPos)
        else: # Snap pos to nearest grid point
          let newPos = (gDb[hitid].pos + delta).snap(self.mGrid, vp)
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
    if self.mGrid.visible:
      self.mGrid.draw(self.mViewPort, self.sdlRenderer, self.size)

    # Try a few methods to draw rectangles
    when defined(noTextureCache):
      self.renderToScreen()
    else:
      self.blitFromTextureCache()

    # Draw various boxes and text, then done
    # self.updateDestinationBox()
    # self.sdlRenderer.renderOutlineRect(self.mDstRect.toPRect(self.mViewPort), Black)
    self.sdlRenderer.renderOutlineRect(self.mAllBbox.toPRect(self.mViewPort).grow(1), Green)
    self.sdlRenderer.renderFilledRect(self.mSelectBox,
                                      fillColor=(r:0, g:102, b:204, a:70).RGBATuple.toColorU32,
                                      penColor=(r:0, g:120, b:215, a:255).RGBATuple.toColorU32)
    var txt: string
    txt &= &"pan: {self.mViewPort.pan}\n"
    txt &= &"zClicks: {self.mViewPort.zClicks}\n"
    txt &= &"level: {self.mViewPort.zCtrl.logStep}\n"
    txt &= &"rawZoom: {self.mViewPort.rawZoom:.3f}\n"
    txt &= &"zoom: {self.mViewPort.zoom:.3f}"
    
    self.sdlRenderer.renderText(self.sdlWindow, txt)
    #self.sdlRenderer.renderText(self.sdlWindow, self.mText)
    self.sdlRenderer.present()

    # release(gLock)
  
  proc init*(self: wBlockPanel, parent: wWindow) = 
    discard
    wSDLPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
    #self.mDstRect = (-100, -100, 200, 200)
    self.mGrid.xSpace = 10
    self.mGrid.ySpace = 10
    self.mGrid.visible = true
    self.mGrid.originVisible = true
    self.mViewPort.doZoom(6400)
    self.mViewPort.pan = (400, 400)

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

    