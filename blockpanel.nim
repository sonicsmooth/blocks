import std/[bitops, math, segfaults, sets, sugar, strformat, tables ]
from std/sequtils import toSeq
import wNim
import winim except PRECT, Color
#from wNim/private/wHelper import `-`
import sdl2
import rects, recttable, sdlframes, db, viewport, grid, pointmath
import userMessages, utils
import render

# TODO: Hover
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
    clickHitIds: seq[RectID]
    dirtyIds:    seq[RectID]
    clickPos:    wPoint # comes from winim (wPoint) not SDL2 (cint)
    lastPos:     wPoint # comes from winim (wPoint) not SDL2 (cint)
    state:       MouseState
    pzState:     PanZoomState
  CacheKey = tuple[id:RectID, selected: bool]
  wBlockPanel* = ref object of wSDLPanel
    mMouseData: MouseData
    mTextureCache: Table[CacheKey, TexturePtr]
    mFirmSelection*: seq[RectID]
    mFillArea*: WType
    mRatio*: float
    mAllBbox*: WRect
    mSelectBox*: WRect
    mDstRect*: WRect
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
  moveTable: array[wKey_Left .. wKey_Down, sdl2.Point] =
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

  proc clearTextureCache*(self:wBlockPanel, id: RectID) =
    # Clear specific id from texture cache
    for sel in [false, true]:
      let key = (id, sel)
      if key in self.mTextureCache:
        self.mTextureCache[key].destroy()
      self.mTextureCache.del(key)

  proc getFromTextureCache(self: wBlockPanel, id: RectID): TexturePtr =
    # Copies surfaces from surfaceCache to textures
    # Requires to be called when resize because of new texture
    let 
      rect = gDb[id]
      key = (id, rect.selected)
      vp = self.mViewPort
    if self.mTextureCache.hasKey(key):
      self.mTextureCache[key]
    else:
      let
        prect = rect.toPRect(vp)
        surface = createRGBSurface(0, prect.w, prect.h, 32, rmask, gmask, bmask, amask)
        swRenderer = createSoftwareRenderer(surface)
      swRenderer.renderDBRect(vp, rect, zero=true)
      let texture = self.sdlRenderer.createTextureFromSurface(surface)
      self.mTextureCache[key] = texture
      texture
  
  proc blitFromTextureCache(self: wBlockPanel) =
    # Copy from texture cache to screen via sdlrenderer
    let
      vp = self.mViewPort
      sz: PxSize = self.size
      screenRect: WRect = (0.PxType, 0.PxType, sz.w, sz.h).toWrect(vp)
    var dstRect: PRect
    for rect in gDb.values:
      if isRectSeparate(rect, screenRect):
        continue
      let pTexture: TexturePtr = self.getFromTextureCache(rect.id)
      dstRect = rect.toPRect(vp, rot=true)
      self.sdlRenderer.copy(pTexture, nil, addr dstRect)
  
  proc renderToScreen(self: wBlockPanel) =
    # Render blocks to screen using default renderer
    let
      vp = self.mViewPort
      sz: PxSize = self.size
      screenRect: WRect = (0.PxType, 0.PxType, sz.w, sz.h).toWrect(vp)
    for rect in gDb.values:
      if isRectSeparate(rect, screenRect):
        continue
      self.sdlRenderer.renderDBRect(vp, rect, zero=false)

  proc onResize(self: wBlockPanel, event: wEvent) =
    # Post user message so top frame can show new size
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_SIZE, event.mWparam, event.mLparam)
  proc updateRatio*(self: wBlockPanel) =
    if gDb.len == 0:
      self.mText = "0.0" #$0.0
      self.mRatio = 0.0
    else:
      self.mAllBbox = gDb.boundingBox().grow(2)
      let ratio = self.mFillArea.float / self.mAllBbox.area.float
      if ratio != self.mRatio:
        self.mRatio = ratio
  proc moveRectsBy(self: wBlockPanel, rectIds: seq[RectId], delta: WPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    # Refer to comments as late as 27ff3c9a056c7b49ffe30d6560e1774091c0ae93
    let rects = gDb[rectIDs]
    for rect in rects:
      moveRectBy(rect, delta)
    self.updateRatio()
    self.refresh(false)
  proc moveRectBy(self: wBlockPanel, rectId: RectId, delta: WPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    #let wdelta: WPoint = delta.toWorld(self.mViewPort)
    #echo delta
    moveRectBy(gDb[rectId], delta)
    self.updateRatio()
    self.refresh(false)
  proc moveRectTo(self: wBlockPanel, rectId: RectId, delta: WPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    #let wdelta: WPoint = delta.toWorld(self.mViewPort)
    #echo delta
    moveRectTo(gDb[rectId], delta)
    self.updateRatio()
    self.refresh(false)
  proc rotateRects(self: wBlockPanel, rectIds: seq[RectId], amt: Rotation) =
    for id in rectIds:
      gDb[id].rotate(amt)
      self.clearTextureCache(id)
    self.updateRatio()
    self.refresh(false)
  proc deleteRects(self: wBlockPanel, rectIds: seq[RectId]) =
    for id in rectIds:
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
      self.moveRectsBy(sel, moveTable[event.keyCode])
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
      else:
        self.rotateRects(sel, R90)
        resetBox()
        self.mMouseData.state = StateNone
    of CmdRotateCW:
      if self.mMouseData.state == StateDraggingRect or 
         self.mMouseData.state == StateLMBDownInRect:
        self.rotateRects(@[self.mMouseData.clickHitIds[^1]], R270)
      else:
        self.rotateRects(sel, R270)
        resetBox()
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
        # Same mouse point represents two different world points before
        # and after zoom.  Calculate delta in world coords, then convert
        # to pixels and use this for pan delta
        let zmWMousePos1 = event.mousePos.toWorld(self.mViewPort)
        self.mViewPort.doZoom(event.wheelRotation)
        let zmWMousePos2 = event.mousePos.toWorld(self.mViewPort)
        let pxDelta = ((zmWMousePos2 - zmWMousePos1) * self.mViewPort.zoom).toPxPoint
        self.mViewPort.doPan((pxDelta.x, pxDelta.y * -1))
        self.clearTextureCache()
        self.mText = $self.mViewPort.zoom
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
          lastSnap: WPoint = self.mGrid.snap(self.mMouseData.lastPos.toWorld(vp))
          newSnap: WPoint = self.mGrid.snap(wmp)
          delta: WPoint = newSnap - lastSnap
        if event.ctrlDown and hitid in sel:
          # Group move should snap by grid amount even if not on grid to start
          self.moveRectsBy(sel, delta)
          # Todo: make snap-to-grid proc like this
          # for id in sel:
          #   let newPos = self.mGrid.snap(gDb[id].pos + delta)
          #   self.moveRectTo(id, newPos)
        else:
          # Snap pos to nearest grid point
          let newPos = self.mGrid.snap(gDb[hitid].pos + delta)
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
        let pbox: PRect = normalizeRectCoords(self.mMouseData.clickPos, event.mousePos)
        self.mSelectBox = pbox.toWRect(vp)
        let newsel = gDb.rectInRects(self.mSelectBox)
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

    #self.mText.setLen(0)
    #self.mText &= modifierText(event)
    #self.mText &= &"State: {self.mMouseData.state}"


# Todo: hovering over
# TODO optimize what gets invalidated during move


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
    
    # # Draw grid
    # if self.mGrid.visible:
    #   self.mGrid.draw(self.mViewPort, self.sdlRenderer, self.size)

    # Try a few methods to draw rectangles
    when defined(textureCache):
      self.blitFromTextureCache()
    else:
      self.renderToScreen()

    # Draw various boxes and text, then done
    if self.mDstRect.w > 0:
      self.sdlRenderer.renderOutlineRect(self.mDstRect.toPRect(self.mViewPort), Black)
    self.sdlRenderer.renderOutlineRect(self.mAllBbox.toPRect(self.mViewPort), Green)
    # self.sdlRenderer.renderFilledRect(self.mSelectBox.toPRect(self.mViewPort),
    #                                   fillColor=(0, 102, 204, 70).toColorU32,
    #                                   penColor=(0, 120, 215, 255).toColorU32)
    self.sdlRenderer.renderText(self.sdlWindow, self.mText)
    self.sdlRenderer.present()

    # release(gLock)
  
  proc init*(self: wBlockPanel, parent: wWindow) = 
    discard
    wSDLPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
    self.mDstRect = (-250, -250, 500, 500)
    self.mGrid.xSpace = 25
    self.mGrid.ySpace = 25
    self.mGrid.visible = true
    self.mGrid.originVisible = true
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

    