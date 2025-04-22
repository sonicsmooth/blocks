import std/[math, segfaults, sets, sugar, strformat, tables ]
from std/sequtils import toSeq, foldl
import wNim
import winim
from wNim/private/wHelper import `-`
import rects, recttable, sdlframes, db
import userMessages, utils
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
  wBlockPanel* = ref object of wSDLPanel
    mSurfaceCache: Table[CacheKey, SurfacePtr]
    mTextureCache: Table[CacheKey, TexturePtr]
    mFirmSelection*: seq[RectID]
    mFillArea*: int
    mRatio*: float
    mAllBbox*: wRect
    mSelectBox*: wRect
    mDstRect*: wRect
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

var 
  mouseData: MouseData
  fontPts: seq[float] = collect(for x in 6..24: x.float)
  fonts: FontTable = collect(
                       for sz in fontPts: 
                         (sz, Font(sz, wFontFamilyRoman))).toTable



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
    
  proc forceRedraw*(self: wBlockPanel, wait: int = 0) = 
    self.refresh(false)
    UpdateWindow(self.mHwnd)

  proc initSurfaceCache*(self: wBlockPanel) =
    # Creates all new surfaces
    for surface in self.mSurfaceCache.values:
      surface.destroy()
    self.mSurfaceCache.clear()
    let font = openFont("fonts/DejaVuSans.ttf", 20)
    for id, rect in gDb:
      for sel in [false, true]:
        self.mSurfaceCache[(id, sel)] = self.rectToSurface(rect, sel, font)

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
    self.initTextureCache() # Todo check whether new renderer onresize
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, USER_SIZE, event.mWparam, event.mLparam)
  
  proc updateRatio*(self: wBlockPanel) =
    self.mAllBbox = gDb.boundingBox()
    let ratio = self.mFillArea.float / self.mAllBbox.area.float
    if ratio != self.mRatio:
      echo ratio
      self.mText = $ratio
      self.mRatio = ratio
  
  proc moveRectsBy(self: wBlockPanel, rectIds: seq[RectId], delta: wPoint) =
    # Common proc to move one or more Rects; used by mouse and keyboard
    # Refer to comments as late as 27ff3c9a056c7b49ffe30d6560e1774091c0ae93
    let rects = gDb[rectIDs]
    for rect in rects:
      moveRectBy(rect, delta)
    self.updateRatio()
    self.refresh(false)
  proc moveRectBy(self: wBlockPanel, rectId: RectId, delta: wPoint) =
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
      mouseData.clickHitIds.setLen(0)
      mouseData.dirtyIds.setLen(0)
      mouseData.clickPos = (0,0)
      mouseData.lastPos = (0,0)
    proc escape() =
      resetMouseData()
      resetBox()
      if mouseData.state == StateDraggingSelect:
        let clrsel = (gDb.selected.toHashSet - self.mFirmSelection.toHashSet).toSeq
        gDb.clearRectSelect(clrsel)
        self.refresh(false)
      mouseData.state = StateNone

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
        mouseData.clickHitIds = gDb.ptInRects(event.mousePos)
        if mouseData.clickHitIds.len > 0: # Click in rect
          mouseData.dirtyIds = gDb.rectInRects(mouseData.clickHitIds[^1])
          mouseData.state = StateLMBDownInRect
        else: # Click in clear area
          mouseData.state = StateLMBDownInSpace
      else:
        discard
    of StateLMBDownInRect:
      let hitid = mouseData.clickHitIds[^1]
      case event.getEventType
      of wEvent_MouseMove:
        mouseData.state = StateDraggingRect
      of wEvent_LeftUp:
        if event.mousePos == mouseData.clickPos: # click and release in rect
          var oldsel = gDb.selected()
          if not event.ctrlDown: # clear existing except this one
            oldsel.excl(hitid)
            gDb.clearRectSelect(oldsel)
          gDb.toggleRectSelect(hitid) 
          mouseData.dirtyIds = oldsel & hitid
          self.refresh(false)
        mouseData.state = StateNone
      else:
        mouseData.state = StateNone
    of StateDraggingRect:
      let hitid = mouseData.clickHitIds[^1]
      let sel = gdb.selected()
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
          self.mFirmSelection = gDb.selected()
        else:
          self.mFirmSelection.setLen(0)
          gDb.clearRectSelect()
      of wEvent_LeftUp:
        let oldsel = gDb.clearRectSelect()
        mouseData.dirtyIds = oldsel
        mouseData.state = StateNone
        self.refresh(false)
      else:
        mouseData.state = StateNone
    of StateDraggingSelect:
      case event.getEventType
      of wEvent_MouseMove:
        self.mSelectBox = normalizeRectCoords(mouseData.clickPos, event.mousePos)
        let newsel = gDb.rectInRects(self.mSelectBox)
        gDb.setRectSelect(self.mFirmSelection)
        gDb.setRectSelect(newsel)
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


  proc onPaint(self: wBlockPanel, event: wEvent) =
    let size = event.window.clientSize
    self.sdlRenderer.setDrawColor(SDLColor self.backgroundColor.rbswap)
    self.sdlRenderer.clear()
    self.sdlRenderer.setDrawBlendMode(BlendMode_Blend)
    
    # Try a few methods to draw rectangles
    when true:
      # Blit to surface from mTextureCache
      for rect in gDb.values:
        let texture = self.mTextureCache[(rect.id, rect.selected)]
        let dstrect = SDLRect rect.towRectNoRot
        let pt = SDLPoint rect.origin
        self.sdlRenderer.copyEx(texture, nil, addr dstrect, -rect.rot.toFloat, addr pt)
    elif false:
      # Blit to surface from mSurfaceCache
      discard
    else:
      # Draw directly to surface
      discard



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
  #   release(gLock)
  
  proc init*(self: wBlockPanel, parent: wWindow) = 
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

