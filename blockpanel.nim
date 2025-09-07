import std/[math, segfaults, sets, sugar, strformat, tables ]
from std/sequtils import toSeq, foldl
import wNim
import winim except PRECT
from wNim/private/wHelper import `-`
import sdl2
import rects, recttable, sdlframes, db
import userMessages, utils
import render
import timeit

# TODO: copy background before Move
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
  MouseData = tuple
    clickHitIds: seq[RectID]
    dirtyIds:    seq[RectID]
    clickPos:    wPoint
    lastPos:     wPoint
    state:       MouseState
  CacheKey = tuple[id:RectID, selected: bool]
  wBlockPanel* = ref object of wSDLPanel
    mMouseData: MouseData
    mSurfaceCache: Table[CacheKey, SurfacePtr]
    mTextureCache: Table[CacheKey, TexturePtr]
    mFirmSelection*: seq[RectID]
    mFillArea*: int
    mRatio*: float
    mAllBbox*: PRect
    mSelectBox*: PRect
    mDstRect*: PRect
    mText*: string
 
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
    [(-1,0), (0, -1), (1, 0), (0, 1)]



wClass(wBlockPanel of wSDLPanel):
  proc forceRedraw*(self: wBlockPanel, wait: int = 0) = 
    self.refresh(false)
    UpdateWindow(self.mHwnd)

  proc rectToSurface(self: wBlockPanel, rect: rects.Rect, sel: bool): SurfacePtr =
    result = createRGBSurface(0, rect.w, rect.h, 32, 
      rmask, gmask, bmask, amask)
    result.renderRect(rect, sel)

  proc initSurfaceCache*(self: wBlockPanel) =
    # Creates all new surfaces
    for surface in self.mSurfaceCache.values:
      surface.destroy()
    self.mSurfaceCache.clear()
    for id, rect in gDb:
      for sel in [false, true]:
        self.mSurfaceCache[(id, sel)] = self.rectToSurface(rect, sel)

  proc initTextureCache*(self: wBlockPanel) =
    # Copies surfaces from surfaceCache to textures
    for texture in self.mTextureCache.values:
      texture.destroy()
    self.mTextureCache.clear()
    for key, surface in self.mSurfaceCache:
      self.mTextureCache[key] = 
        self.sdlRenderer.createTextureFromSurface(surface)



  proc onResize(self: wBlockPanel, event: wEvent) =
    # Post user message so top frame can show new size
    self.initTextureCache()
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_SIZE, event.mWparam, event.mLparam)
  proc updateRatio*(self: wBlockPanel) =
    if gDb.len == 0:
      self.mText = $0.0
      self.mRatio = 0.0
    else:
      let bbox = gDb.boundingBox()
      self.mAllBbox = bbox # implicitly calls converter in utils.nim
      let ratio = self.mFillArea.float / self.mAllBbox.area.float
      if ratio != self.mRatio:
        echo ratio
        self.mText = $ratio
        self.mRatio = ratio
  proc moveRectsBy(self: wBlockPanel, rectIds: seq[RectId], delta: sdl2.Point) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    # Refer to comments as late as 27ff3c9a056c7b49ffe30d6560e1774091c0ae93
    let rects = gDb[rectIDs]
    for rect in rects:
      moveRectBy(rect, delta)
    self.updateRatio()
    self.refresh(false)
  proc moveRectBy(self: wBlockPanel, rectId: RectId, delta: sdl2.Point) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    moveRectBy(gDb[rectId], delta)
    self.updateRatio()
    self.refresh(false)
  proc deleteRects(self: wBlockPanel, rectIds: seq[RectId]) =
    for id in rectIds:
      gDb.del(id) # Todo: check whether this deletes rect
      for sel in [true, false]:
        self.mTextureCache[(id, sel)].destroy()
        self.mTextureCache.del((id, sel))
    self.mFillArea = gDb.fillArea()
    self.updateRatio()
    self.refresh(false)
  proc rotateRects(self: wBlockPanel, rectIds: seq[RectId], amt: Rotation) =
    for id in rectIds:
      gDb[id].rotate(amt)
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
      self.mMouseData.clickPos = (0,0)
      self.mMouseData.lastPos = (0,0)
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

    case self.mMouseData.state
    of StateNone:
      case event.getEventType
      of wEvent_LeftDown:
        SetFocus(self.mHwnd) # Selects region so it captures keyboard
        self.mMouseData.clickPos = event.mousePos
        self.mMouseData.lastPos  = event.mousePos
        self.mMouseData.clickHitIds = gDb.ptInRects(event.mousePos)
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
        let delta = event.mousePos - self.mMouseData.lastPos
        if event.ctrlDown and hitid in sel:
          self.moveRectsBy(sel, delta)
        else:
          self.moveRectBy(hitid, delta)
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
        self.mSelectBox = normalizeRectCoords(self.mMouseData.clickPos, event.mousePos)
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

    self.mText.setLen(0)
    self.mText &= modifierText(event)
    self.mText &= &"State: {self.mMouseData.state}"


# Todo: hovering over
# TODO optimize what gets invalidated during move


#[
Rendering options for pure SDL
1. Blitting to window renderer...
  A. ...from sdl Texture cache (copied from sdl surface cache on init and resize)
  B. ...from sdl surface cache
2. Rendering in real time directly to sdl surface

Rendering options for SDL and pixie
1. Blitting to window renderer...
  A. ...from sdl Texture cache (copied from pixie image cache on init and resize)
  C. ...from pixie image cache
2. Rendering in real time  
  B. Render to pixie image then blit to sdl surface



]# 

  proc blitFromTextureCache(self: wBlockPanel) =
    # Copy from texture cache to screen via sdlrenderer
    for rect in gDb.values:
      let texture = self.mTextureCache[(rect.id, rect.selected)]
      let dstrect = rect.toRectNoRot
      let pt = rect.origin
      self.sdlRenderer.copyEx(texture, nil, addr dstrect, -rect.rot.toFloat, addr pt)


  proc blitFromSurfaceCache(self: wBlockPanel) = 
    # Copy from surface cache to screen via surface ptr
    let dstsurface = self.sdlWindow.getSurface()
    for rect in gDb.values:
      dstsurface.renderRect(rect, rect.selected)


      # let dstrect = rect.PRect
      # let pdr = cast[ptr sdl2.Rect](addr dstrect)
      # #echo ""
      # #dump dstrect
      # #dump (cast[int] (addr dstrect))

      # #let srcsurface = self.mSurfaceCache[(rect.id, rect.selected)]
      # let srcsurface = self.rectToSurface(rect, false)
      # let srcrect: sdl2.Rect = (0, 0, dstrect.w, dstrect.h)
      # let psr = cast[ptr sdl2.Rect](addr srcrect)
      
      # blitSurface(srcsurface, nil, dstsurface, nil)
      
      # #dump (cast [int] (addr srcrect))
      
      # #echo "src: ", srcsurface.w, ", ", srcsurface.h
      # #echo "srcrect: ", srcrect

      # # Problems with rotation
      # #discard lowerBlit(srcsurface, psr, dstsurface, pdr)
      # #discard lowerBlit(srcsurface, nil, dstsurface, pdr)



  proc onPaint(self: wBlockPanel, event: wEvent) =
    self.sdlRenderer.setDrawColor(self.backgroundColor.toColor())
    self.sdlRenderer.clear()
    

    # Try a few methods to draw rectangles
    #timeOnce("test-once"):
    when true:
      self.blitFromTextureCache()
    elif false:
      self.blitFromSurfaceCache()
    else:
      # Draw directly to surface
      discard

    # Draw various boxes and text, then done
    if self.mDstRect.w > 0:
      self.sdlRenderer.renderDestinationBox(self.mDstRect)
    self.sdlRenderer.renderBoundingBox(self.mAllBbox)
    self.sdlRenderer.renderSelectionBox(self.mSelectBox)
    self.sdlRenderer.renderText(self.sdlWindow, self.mText)
    self.sdlRenderer.present()

    # release(gLock)
  
  proc init*(self: wBlockPanel, parent: wWindow) = 
    discard
    wSDLPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue
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

    