import std/[sets, 
            sequtils]
import wNim
import pointmath
import routing
import appopts
import zoomctrl
from utils import excl
import rects
import document

type
  Command = enum
    CmdEscape
    CmdMove
    CmdDelete
    CmdRotateCCW
    CmdRotateCW
    CmdSelect
    CmdSelectAll
  KeyCode* = enum
    KeyNone, KeyEsc, KeySpace, KeyEnter,
    KeyDelete, KeyInsert, KeyBack, KeyPgUp, KeyPgDn,
    KeyCtrl, KeyShift, KeyAlt,
    KeyUp, KeyDn, KeyLeft, KeyRight,
    KeyA, KeyB, KeyC, KeyD, KeyE, KeyF, KeyG, KeyH, KeyI,
    KeyJ, KeyK, KeyL, KeyM, KeyN, KeyO, KeyP, KeyQ, KeyR,
    KeyS, KeyT, KeyU, KeyV, KeyW, KeyX, KeyY, KeyZ,
    Key0, Key1, Key2, Key3, Key4, Key5, Key6, Key7,
    Key8, Key9
  Key* = tuple[keyCode: KeyCode, ctrl: bool, alt: bool, shift: bool]
  CmdTable = Table[Key, Command]

  # MouseMove* = object
  #   pos: PxPoint
  #   ctrl, alt, shift: bool
  #   wheel: int

    
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
    clickPos:    PxPoint
    lastPos:     PxPoint
    state:       MouseState
    pzState:     PanZoomState

  # TODO: editor should have pointer to doc.grid directly

  Editor* = ref object of RootObj
    doc*:          Document
    mouseData:     MouseData
    selectBox*:    PRect # Selection box
    allBbox*:      WRect # Bounding box of everything
    dstRect*:      WRect # Where components will be moved to
    text*:         string
    fillArea*:     WType
    ratio:         float
    firmSelection: seq[CompID]
    viewport*:     Viewport
    invalidate*:   proc() {.gcsafe.}

const 
  cmdTable: CmdTable = 
    {(keyCode: KeyEsc,    ctrl: false, alt: false, shift: false ): CmdEscape,
     (keyCode: KeyLeft,   ctrl: false, alt: false, shift: false ): CmdMove,
     (keyCode: KeyUp,     ctrl: false, alt: false, shift: false ): CmdMove,
     (keyCode: KeyRight,  ctrl: false, alt: false, shift: false ): CmdMove,
     (keyCode: KeyDn,     ctrl: false, alt: false, shift: false ): CmdMove,
     (keyCode: KeyLeft,   ctrl: false, alt: false, shift: true  ): CmdMove,
     (keyCode: KeyUp,     ctrl: false, alt: false, shift: true  ): CmdMove,
     (keyCode: KeyRight,  ctrl: false, alt: false, shift: true  ): CmdMove,
     (keyCode: KeyDn,     ctrl: false, alt: false, shift: true  ): CmdMove,
     (keyCode: KeyDelete, ctrl: false, alt: false, shift: false ): CmdDelete,
     (keyCode: KeySpace,  ctrl: false, alt: false, shift: false ): CmdRotateCCW,
     (keyCode: KeySpace,  ctrl: false, alt: false, shift: true  ): CmdRotateCW,
     (keyCode: KeyA,      ctrl: true,  alt: false, shift: false ): CmdSelectAll }.toTable
  moveTable: array[KeyUp .. KeyRight, WPoint] =
    [(0, 1), (0, -1), (-1, 0), (1, 0)]


proc newEditor*(zc: ZoomCtrl): Editor =
  result = new Editor
  # assign viewport like 
  result.viewport  = newViewport(pan=(400,400), clicks=0, zCtrl=zc)
  # ... but zc was created before, with grid
  # all other fields can take their default values
  # and are assigned later

proc updateDestinationBox*(self: Editor) =
  let 
    marg = 25
    sz = self.viewport.clientSize
    pdstrect: PRect = (marg, marg, sz.w - 2*marg, sz.h - 2*marg)
  self.dstRect = pdstrect.toWRect(self.viewport)

proc updateBoundingBox*(self: Editor) =
  self.allBbox = self.doc.db.boundingBox()

proc updateRatio*(self: Editor) =
  if self.doc.db.len == 0:
    self.ratio = 0.0
  else:
    let ratio = self.fillArea.float / self.allBbox.area.float
    if ratio != self.ratio:
      self.ratio = ratio
proc moveRectsBy(self: Editor, compIDs: seq[CompID], delta: WPoint) =
  # Common proc to move one or more Rects; used by mouse and keyboard
  # Refer to comments as late as 27ff3c9a056c7b49ffe30d6560e1774091c0ae93
  let rects = self.doc.db[compIDs]
  for rect in rects:
    moveRectBy(rect, delta)
  self.invalidate()
proc moveRectBy(self: Editor, compID: CompID, delta: WPoint) =
  # Common proc to move one or more Rects; used by mouse and keyboard
  moveRectBy(self.doc.db[compID], delta)
  self.invalidate()
proc moveRectTo(self: Editor, compID: CompID, delta: WPoint) =
  # Common proc to move one or more Rects; used by mouse and keyboard
  moveRectTo(self.doc.db[compID], delta)
  self.invalidate()
proc rotateRects(self: Editor, compIDs: seq[CompID], amt: Rotation) =
  for id in compIDs:
    self.doc.db[id].rotate(amt)
    ##!!!!!self.clearTextureCache(id)
  self.invalidate()
proc deleteRects(self: Editor, compIDs: seq[CompID]) =
  for id in compIDs:
    self.doc.db.del(id) # Todo: check whether this deletes rect
    ##!!!!!self.clearTextureCache(id)
  self.fillArea = self.doc.db.fillArea()
  self.invalidate()
proc selectAll(self: Editor) =
  self.doc.db.setRectSelect()
  self.invalidate()
proc selectNone(self: Editor) =
  self.doc.db.clearRectSelect()
  self.invalidate()
# proc isModifierEvent(event: wEvent): bool = 
#   event.keyCode == wKey_Ctrl or
#   event.keyCode == wKey_Shift or
#   event.keyCode == wKey_Alt
#proc evaluateHovering(self: Editor, event: wEvent): bool {.discardable.} =
proc evaluateHovering(self: Editor, pos: PxPoint): bool {.discardable.} =
  # clear and set hovering
  # Return true if something changed
  if gAppOpts.enableHover:
    let
      cleared = self.doc.db.clearRectHovering()
      newset = self.doc.db.setRectHovering(self.doc.db.ptInRects(pos, self.viewport))
    len(cleared) > 0 or len(newset) > 0
  else:
    false
proc processKeyDown*(self: Editor, key: Key) =
  # event must not be a modifier key
  proc resetBox() =
    self.selectBox = (0,0,0,0)
    self.invalidate()
  proc resetMouseData() = 
    self.mouseData.clickHitIds.setLen(0)
    self.mouseData.dirtyIds.setLen(0)
    self.mouseData.clickPos = (0, 0)
    self.mouseData.lastPos = (0, 0)
  proc escape() =
    resetMouseData()
    resetBox()
    if self.mouseData.state == StateDraggingSelect:
      let clrsel = (self.doc.db.selected.toHashSet - self.firmSelection.toHashSet).toSeq
      self.doc.db.clearRectSelect(clrsel)
      self.invalidate()
    self.mouseData.state = StateNone

  # Stay only if we have a legitimate key combination
  #let k = (event.keycode, event.ctrlDown, event.shiftDown, event.altDown)
  if not (key in cmdTable):
    escape()
    return

  let sel = self.doc.db.selected()
  case cmdTable[key]:
  of CmdEscape:
    escape()
  of CmdMove:
    let
      md: WPoint = 
        if key.shift:
          minDelta(self.doc.grid, scale=Tiny)
        else:
          minDelta(self.doc.grid, scale=Minor)
      moveby: WPoint = md .* moveTable[key.keyCode]
    self.moveRectsBy(sel, moveBy)
    resetBox()
    self.mouseData.state = StateNone
  of CmdDelete:
    self.deleteRects(sel)
    resetBox()
    self.mouseData.state = StateNone
  of CmdRotateCCW:
    if self.mouseData.state == StateDraggingRect or 
        self.mouseData.state == StateLMBDownInRect:
      self.rotateRects(@[self.mouseData.clickHitIds[^1]], R90)
      #self.evaluateHovering(event)
      self.evaluateHovering(self.mouseData.lastPos)
      self.invalidate()
    else:
      self.rotateRects(sel, R90)
      #self.evaluateHovering(event)
      self.evaluateHovering(self.mouseData.lastPos)
      resetBox()
      self.invalidate()
      self.mouseData.state = StateNone
  of CmdRotateCW:
    if self.mouseData.state == StateDraggingRect or 
        self.mouseData.state == StateLMBDownInRect:
      self.rotateRects(@[self.mouseData.clickHitIds[^1]], R270)
      #self.evaluateHovering(event)
      self.evaluateHovering(self.mouseData.lastPos)
      self.invalidate()
    else:
      self.rotateRects(sel, R270)
      #self.evaluateHovering(event)
      self.evaluateHovering(self.mouseData.lastPos)
      resetBox()
      self.invalidate()
      self.mouseData.state = StateNone
  of CmdSelect:
    discard
  of CmdSelectAll:
    self.selectAll()
    self.selectBox = (0,0,0,0)
    self.mouseData.state = StateNone

proc processMouseEvent*(self: Editor, event: wEvent) = 
  # Unified event processing
  # Separate specific events (eg shft+LMB) from state changes
  # For example, StateLMBDownInRect should be renamed to
  # something like StateSelectStartInRect, and the event
  # that gets into that state is MainSelector which comes 
  # from mouseEvent == wEvent_LeftDown.
  # so wEvent_LeftDown is mapped to MainSelector, which triggers
  # state change from None to StateSelectStartInRect
  # Also dragging is delayed by one event; fix it.

  
  let 
    vp = self.viewport
    wmp = event.mousePos.toWorld(vp)
  
  case self.mouseData.pzState:
  of PZStateNone:
    case event.getEventType
    of wEvent_RightDown:
      self.mouseData.clickPos = event.mousePos
      self.mouseData.lastPos  = event.mousePos
      self.mouseData.pzState = PZStateRMBDown
    of wEvent_RightUp:
      self.mouseData.pzState = PZStateNone
    of wEvent_MouseWheel:
      # Keep mouse location in the same spot during zoom.
      doAdaptivePanZoom(self.viewport, event.wheelRotation, event.mousePos)
      # Tell the world
      sendToListeners(idMsgGridZoom, 0, 0)
      #!!!!!!self.clearTextureCache()
      self.invalidate()
    else:
      discard
  of PZStateRMBDown:
    case event.getEventType
    of wEvent_MouseMove:
      let deltaPx: PxPoint = (event.mousePos.x - self.mouseData.lastPos.x,
                              event.mousePos.y - self.mouseData.lastPos.y)
      self.mouseData.lastPos = event.mousePos
      self.viewport.doPan(deltaPx)
      self.invalidate()
    of wEvent_RightUp:
      self.mouseData.pzState = PZStateNone
    else:
      discard
  else:
    discard

  case self.mouseData.state
  of StateNone:
    case event.getEventType
    of wEvent_MouseMove:
      if self.mouseData.pzState == PZStateNone:
        if self.evaluateHovering(event.mousePos):
          self.invalidate()
      else:
        discard
    of wEvent_LeftDown:
      self.mouseData.clickPos = event.mousePos
      self.mouseData.lastPos  = event.mousePos
      self.mouseData.clickHitIds = self.doc.db.ptInRects(wmp)
      if self.mouseData.clickHitIds.len > 0: # Click in rect
        self.mouseData.dirtyIds = self.doc.db.rectInRects(self.mouseData.clickHitIds[^1])
        self.mouseData.state = StateLMBDownInRect
      else: # Click in clear area
        self.mouseData.state = StateLMBDownInSpace
    else:
      discard
  of StateLMBDownInRect:
    let hitid = self.mouseData.clickHitIds[^1]
    case event.getEventType
    of wEvent_MouseMove:
      self.mouseData.state = StateDraggingRect
    of wEvent_LeftUp:
      if event.mousePos.PxPoint == self.mouseData.clickPos: # click and release in rect
        var oldsel = self.doc.db.selected()
        if not event.ctrlDown: # clear existing except this one
          oldsel.excl(hitid)
          self.doc.db.clearRectSelect(oldsel)
        self.doc.db.toggleRectSelect(hitid) 
        self.mouseData.dirtyIds = oldsel & hitid
        self.invalidate()
      self.mouseData.state = StateNone
    else:
      self.mouseData.state = StateNone
  of StateDraggingRect:
    let hitid = self.mouseData.clickHitIds[^1]
    let sel = self.doc.db.selected()
    case event.getEventType
    of wEvent_MouseMove:
      let
        scale = self.doc.grid.recommendScale(event.shiftDown)
        lastSnap: WPoint = self.mouseData.lastPos.toWorld(vp).snap(self.doc.grid, scale=scale)
        newSnap: WPoint = wmp.snap(self.doc.grid, scale=scale)
        delta: WPoint = newSnap - lastSnap
      if event.ctrlDown and hitid in sel:
        # Group move should snap by grid amount even if not on grid to start
        self.moveRectsBy(sel, delta)
        # Todo: make snap-to-grid proc like this
        # for id in sel:
        #   let newPos = self.grid.mSnap(self.doc.db[id].pos + delta)
        #   self.moveRectTo(id, newPos)
      else: # Snap pos to nearest grid point
        let newPos = (self.doc.db[hitid].pos + delta).snap(self.doc.grid, scale=scale)
        self.moveRectTo(hitid, newPos)
      self.mouseData.lastPos = event.mousePos
      self.invalidate()
    else:
      self.mouseData.state = StateNone
  of StateLMBDownInSpace:
    case event.getEventType
    of wEvent_MouseMove:
      self.mouseData.state = StateDraggingSelect
      if event.ctrlDown:
        self.firmSelection = self.doc.db.selected()
      else:
        self.firmSelection.setLen(0)
        self.doc.db.clearRectSelect()
    of wEvent_LeftUp:
      let oldsel = self.doc.db.clearRectSelect()
      self.mouseData.dirtyIds = oldsel
      self.mouseData.state = StateNone
      self.invalidate()
    else:
      self.mouseData.state = StateNone
  of StateDraggingSelect:
    case event.getEventType
    of wEvent_MouseMove:
      let pbox: PRect = normalizePRectCoords(self.mouseData.clickPos, event.mousePos)
      self.selectBox = pbox
      let newsel = self.doc.db.rectInRects(self.selectBox, vp)
      self.doc.db.clearRectSelect()
      self.doc.db.setRectSelect(self.firmSelection)
      self.doc.db.setRectSelect(newsel)
      self.invalidate()
    of wEvent_LeftUp:
      self.selectBox = (0,0,0,0)
      self.mouseData.state = StateNone
      self.invalidate()
    else:
      self.mouseData.state = StateNone
