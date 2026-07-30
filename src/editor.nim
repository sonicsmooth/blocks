import std/[sets, 
            sequtils]
import wNim
import pointmath
import appopts
import zoomctrl
import reporting
from utils import excl
import rects
import document

type
  MouseEventKind* = enum mekNone, mekMove, mekDown, mekUp, mekDbl, 
                    mekWheelVert, mekWheelHoriz
  #MouseButton* = enum mbNone, mbLeft, mbMid, mbRight
  MouseEdge* = enum mbeNone, mbeLeftDown, mbeLeftUp, mbeMidDown, mbeMidUp, mbeRightDown, mbeRightUp
  MouseEvt* = tuple
    pos: PxPoint
    kind: MouseEventKind
    mbLeft, mbMid, mbRight: bool # what is true immediately after event
    edge: MouseEdge # what button caused the event
    ctrl, alt, shift: bool
    wheelDelta: int
    #button: MouseButton # what is true immediately after event
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
  Command = enum
    CmdEscape
    CmdMove
    CmdDelete
    CmdRotateCCW
    CmdRotateCW
    CmdSelect
    CmdSelectAll

  MouseState = enum
    StateNone
    StateLMBDownInComp
    StateLMBDownInSpace
    StateDraggingComp
    StateDraggingSpace
  PanZoomState = enum
    PZStateNone
    PZStateRMBDown
    PZStateRMBMoving
  MouseData = tuple
    clickHitIds: seq[CompID]
    clickPos:    PxPoint
    lastPos:     PxPoint
    state:       MouseState
    pzState:     PanZoomState


  Editor* = ref object of RootObj
    doc*:          Document
    viewport*:     Viewport
    mouseData:     MouseData
    selectBox*:    PRect # Selection box
    allBbox*:      WRect # Bounding box of everything
    dstRect*:      WRect # Where components will be moved to
    text*:         string
    fillArea*:     WType
    ratio:         float
    hovering*:     HoverSet
    selected*:     SelectedSet
    firmSelection: seq[CompID]
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

proc `$`*(k: Key): string =
  if k.ctrl: result &= "ctrl-"
  if k.alt: result &= "alt-"
  if k.shift: result &= "shft-"
  result &= $k.keyCode

proc newEditor*(zc: ZoomCtrl): Editor =
  result = new Editor
  # assign viewport like 
  result.viewport  = newViewport(pan=(400,400), clicks=0, zCtrl=zc)
  # ... but zc was created before, with grid
  # all other fields can take their default values
  # and are assigned later
  result.hovering = newHoverSet()
  result.selected = newSelectedSet()

proc isReady*(self: Editor): bool =
  if self.doc.isNil: return reportNil("editor.doc")
  if self.viewport.isNil: return reportNil("editor.viewport")
  if not self.doc.isReady(): return reportNotReady("editor.doc")
  if not self.viewport.isReady(): return reportNotReady("editor.viewport")
  true

proc randomizeRects*(self: Editor, qty: int, region: WRect) =
  self.doc.db.randomizeRectsAll(qty, region, true)
  self.hovering[].clear()
  self.selected[].clear()

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
  self.selected.setAll(self.doc.db)
  self.invalidate()
proc selectNone(self: Editor) =
  self.selected.clearAll()
  self.invalidate()
proc selectedItems*(self: Editor): seq[CompID] =
  self.selected.trueItems
proc hoveringItems*(self: Editor): seq[CompID] =
  self.hovering.trueItems
proc isSelected*(self: Editor, id: CompID): bool =
  id in self.selected[]
proc isHovering*(self: Editor, id: CompID): bool =
  id in self.hovering[]
# proc isModifierEvent(event: wEvent): bool = 
#   event.keyCode == wKey_Ctrl or
#   event.keyCode == wKey_Shift or
#   event.keyCode == wKey_Alt
proc evaluateHovering(self: Editor, pos: PxPoint): bool {.discardable.} =
  # Mutate self.hovering
  # Return true if something changed
  let oldhover = self.hovering[].toSeq()
  if gAppOpts.enableHover:
    self.hovering.clearAll()
    let hoveringComps = self.doc.db.ptInComps(pos, self.viewport)
    self.hovering.setSome(hoveringComps)
    hoveringComps != oldhover
  else:
    false
proc processKeyDown*(self: Editor, key: Key) =
  when defined(debug):
    echo $key
  return
  # event must not be a modifier key
  proc resetBox() =
    self.selectBox = (0,0,0,0)
    self.invalidate()
  proc resetMouseData() = 
    self.mouseData.clickHitIds.setLen(0)
    # self.mouseData.dirtyIds.setLen(0)
    self.mouseData.clickPos = (0, 0)
    self.mouseData.lastPos = (0, 0)
  proc escape() =
    resetMouseData()
    resetBox()
    if self.mouseData.state == StateDraggingSpace:
      let clrsel = (self.selected.trueItems.toHashSet - self.firmSelection.toHashSet).toSeq
      self.selected.clearSome(clrsel)
      self.invalidate()
    self.mouseData.state = StateNone

  # Stay only if we have a legitimate key combination
  #let k = (event.keycode, event.ctrlDown, event.shiftDown, event.altDown)
  if not (key in cmdTable):
    escape()
    return

  let sel = self.selected.trueItems
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
    if self.mouseData.state == StateDraggingComp or 
        self.mouseData.state == StateLMBDownInComp:
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
    if self.mouseData.state == StateDraggingComp or 
        self.mouseData.state == StateLMBDownInComp:
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

proc processMouseMoveEvent*(self: Editor, event: MouseEvt) = 
  # Separate specific events (eg shft+LMB) from state changes
  # For example, StateLMBDownInComp should be renamed to
  # something like StateSelectStartInRect, and the event
  # that gets into that state is MainSelector which comes 
  # from mouseEvent == wEvent_LeftDown.
  # so wEvent_LeftDown is mapped to MainSelector, which triggers
  # state change from None to StateSelectStartInRect
  # Also dragging is delayed by one event; fix it.
  #echo event
  #return
  
  let 
    vp = self.viewport
    # wmp = event.pos.toWorld(vp)
  
  # case self.mouseData.pzState:
  # of PZStateNone:
  #   case event.getEventType
  #   of wEvent_RightDown:
  #     self.mouseData.clickPos = event.pos
  #     self.mouseData.lastPos  = event.pos
  #     self.mouseData.pzState = PZStateRMBDown
  #   of wEvent_RightUp:
  #     self.mouseData.pzState = PZStateNone
  #   of wEvent_MouseWheel:
  #     # Keep mouse location in the same spot during zoom.
  #     doAdaptivePanZoom(self.viewport, event.wheelRotation, event.pos)
  #     # Tell the world
  #     sendToListeners(idMsgGridZoom, 0, 0)
  #     #!!!!!!self.clearTextureCache()
  #     self.invalidate()
  #   else:
  #     discard
  # of PZStateRMBDown:
  #   case event.getEventType
  #   of wEvent_MouseMove:
  #     let deltaPx: PxPoint = (event.pos.x - self.mouseData.lastPos.x,
  #                             event.pos.y - self.mouseData.lastPos.y)
  #     self.mouseData.lastPos = event.pos
  #     self.viewport.doPan(deltaPx)
  #     self.invalidate()
  #   of wEvent_RightUp:
  #     self.mouseData.pzState = PZStateNone
  #   else:
  #     discard
  # else:
  #   discard

  case self.mouseData.state
  of StateNone:
    # case event.getEventType
    # of wEvent_MouseMove:
    if self.mouseData.pzState == PZStateNone:
      if self.evaluateHovering(event.pos):
        self.invalidate()
  else:
    discard
    # of wEvent_LeftDown:
    #   self.mouseData.clickPos = event.pos
    #   self.mouseData.lastPos  = event.pos
    #   self.mouseData.clickHitIds = self.doc.db.ptInComps(wmp)
    #   if self.mouseData.clickHitIds.len > 0: # Click in rect
    #     #self.mouseData.dirtyIds = self.doc.db.rectInComps(self.mouseData.clickHitIds[^1])
    #     self.mouseData.state = StateLMBDownInComp
    #   else: # Click in clear area
    #     self.mouseData.state = StateLMBDownInSpace
    # else:
      # discard
  # of StateLMBDownInComp:
  #   let hitid = self.mouseData.clickHitIds[^1]
  #   case event.getEventType
  #   of wEvent_MouseMove:
  #     self.mouseData.state = StateDraggingComp
  #   of wEvent_LeftUp:
  #     if event.pos.PxPoint == self.mouseData.clickPos: # click and release in rect
  #       var oldsel = self.doc.db.selected()
  #       if not event.ctrlDown: # clear existing except this one
  #         oldsel.excl(hitid)
  #         self.doc.db.clearRectSelect(oldsel)
  #       self.doc.db.toggleRectSelect(hitid) 
  #       #self.mouseData.dirtyIds = oldsel & hitid
  #       self.invalidate()
  #     self.mouseData.state = StateNone
  #   else:
  #     self.mouseData.state = StateNone
  # of StateDraggingComp:
  #   let hitid = self.mouseData.clickHitIds[^1]
  #   let sel = self.doc.db.selected()
  #   case event.getEventType
  #   of wEvent_MouseMove:
  #     let
  #       scale = self.doc.grid.recommendScale(event.shiftDown)
  #       lastSnap: WPoint = self.mouseData.lastPos.toWorld(vp).snap(self.doc.grid, scale=scale)
  #       newSnap: WPoint = wmp.snap(self.doc.grid, scale=scale)
  #       delta: WPoint = newSnap - lastSnap
  #     if event.ctrlDown and hitid in sel:
  #       # Group move should snap by grid amount even if not on grid to start
  #       self.moveRectsBy(sel, delta)
  #       # Todo: make snap-to-grid proc like this
  #       # for id in sel:
  #       #   let newPos = self.grid.mSnap(self.doc.db[id].pos + delta)
  #       #   self.moveRectTo(id, newPos)
  #     else: # Snap pos to nearest grid point
  #       let newPos = (self.doc.db[hitid].pos + delta).snap(self.doc.grid, scale=scale)
  #       self.moveRectTo(hitid, newPos)
  #     self.mouseData.lastPos = event.pos
  #     self.invalidate()
  #   else:
  #     self.mouseData.state = StateNone
  # of StateLMBDownInSpace:
  #   case event.getEventType
  #   of wEvent_MouseMove:
  #     self.mouseData.state = StateDraggingSpace
  #     if event.ctrlDown:
  #       self.firmSelection = self.doc.db.selected()
  #     else:
  #       self.firmSelection.setLen(0)
  #       self.doc.db.clearRectSelect()
  #   of wEvent_LeftUp:
  #     let oldsel = self.doc.db.clearRectSelect()
  #     #self.mouseData.dirtyIds = oldsel
  #     self.mouseData.state = StateNone
  #     self.invalidate()
  #   else:
  #     self.mouseData.state = StateNone
  # of StateDraggingSpace:
  #   case event.getEventType
  #   of wEvent_MouseMove:
  #     let pbox: PRect = normalizePRectCoords(self.mouseData.clickPos, event.pos)
  #     self.selectBox = pbox
  #     let newsel = self.doc.db.rectInComps(self.selectBox, vp)
  #     self.doc.db.clearRectSelect()
  #     self.doc.db.setRectSelect(self.firmSelection)
  #     self.doc.db.setRectSelect(newsel)
  #     self.invalidate()
  #   of wEvent_LeftUp:
  #     self.selectBox = (0,0,0,0)
  #     self.mouseData.state = StateNone
  #     self.invalidate()
    # else:
    #   self.mouseData.state = StateNone

proc processMouseWheelEvent*(self: Editor, event: MouseEvt) = 
  echo event

proc processMouseButtonEvent*(self: Editor, event: MouseEvt) = 
  let hoveringComps = self.doc.db.ptInComps(event.pos, self.viewport)
  let isHovering = hoveringComps.len > 0
  # Down events can watch just the button of interest so 
  # mouse state and zoom states can start independently
  # But up events need to watch all buttons so as not to
  # change the wrong state.  This 
  if event.edge == mbeLeftDown:
    self.mouseData.clickPos = event.pos
    if isHovering:
      self.mouseData.state = StateLMBDownInComp
    else:
      self.mouseData.state = StateLMBDownInSpace
  elif event.edge == mbeLeftUp:
    self.mouseData.state = StateNone
    if isHovering:
      let topComp = hoveringComps[^1]
      if event.ctrl:
        self.selected.toggleOne(topComp)
      else:
        self.selected.clearAll()
        self.selected.setOne(topComp)
    else:
      self.selected.clearAll()
    self.invalidate()
  echo self.selected[]
  echo self.mouseData.state

