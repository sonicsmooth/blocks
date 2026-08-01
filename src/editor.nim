import std/[options,
            sets, 
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
  MouseEdge* = enum mbeNone, mbeLeftDown, mbeLeftUp, mbeMidDown, mbeMidUp, mbeRightDown, mbeRightUp
  MouseEvt* = tuple
    pos: PxPoint
    kind: MouseEventKind
    mbLeft, mbMid, mbRight: bool # what is true immediately after event
    edge: MouseEdge # what button caused the event
    ctrl, alt, shift: bool
    wheelDelta: int
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
    StateSelectDownInComp
    StateSelectDownInSpace
    StateDraggingComp
    StateDraggingSpace
  PanZoomState = enum
    PZStateNone
    PZStateRMBDown
    PZStateRMBMoving
  MouseData = tuple
    clickHitId : Option[CompID]
    clickPos:    Option[PxPoint]
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
    tmpSelected:  SelectedSet
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
  result.tmpSelected = newSelectedSet()

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
  for rect in self.doc.db[compIDs]:
    moveRectBy(rect, delta)
  #self.invalidate()
# proc moveRectBy(self: Editor, compID: CompID, delta: WPoint) =
#   # Common proc to move one or more Rects; used by mouse and keyboard
#   moveRectBy(self.doc.db[compID], delta)
#   #self.invalidate()
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
# proc selectAll(self: Editor) =
#   self.selected.setAll(self.doc.db)
#   self.invalidate()
# proc selectNone(self: Editor) =
#   self.selected.clearAll()
#   self.invalidate()
# proc selectedItems*(self: Editor): seq[CompID] =
#   self.selected.trueItems
# proc hoveringItems*(self: Editor): seq[CompID] =
#   self.hovering.trueItems
proc isSelected*(self: Editor, id: CompID): bool =
  id in self.selected[] or 
  id in self.tmpSelected[]
proc isHovering*(self: Editor, id: CompID): bool =
  id in self.hovering[]
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
proc resetMouseData(self: Editor) = 
  self.mouseData.clickHitId = none(CompId)
  self.mouseData.clickPos = none(PxPoint)
  self.mouseData.state = StateNone
  self.mouseData.pzState = PZStateNone

proc processKeyDown*(self: Editor, key: Key) =
  case cmdTable[key]:
  of CmdEscape:
    self.resetMouseData()
    self.selectBox = (0,0,0,0)
    self.tmpSelected.clearAll()
    self.invalidate()
  of CmdMove:
    let
      sc = if key.shift: Tiny else: Minor
      md: WPoint = minDelta(self.doc.grid, scale=sc)
      moveby: WPoint = md .* moveTable[key.keyCode]
    self.moveRectsBy(self.selected.trueItems, moveBy)
    self.resetMouseData()
    self.selectBox = (0,0,0,0)
    self.invalidate()
  of CmdDelete:
    self.deleteRects(self.selected.trueItems)
    self.resetMouseData()
    self.selectBox = (0,0,0,0)
    self.invalidate()
  # TODO: implement group rotation with ctrl
  of CmdRotateCCW:
    case self.mouseData.state
    of StateNone:
      self.rotateRects(self.selected.trueItems, R90)
    of StateSelectDownInComp, StateDraggingComp:
      self.rotateRects(@[self.mouseData.clickHitId.get], R90)
    of StateSelectDownInSpace, StateDraggingSpace:
      self.selectBox = (0,0,0,0)
      self.mouseData.state = StateNone
    self.invalidate()
  of CmdRotateCW:
    case self.mouseData.state
    of StateNone:
      self.rotateRects(self.selected.trueItems, R270)
    of StateSelectDownInComp, StateDraggingComp:
      self.rotateRects(@[self.mouseData.clickHitId.get], R270)
    of StateSelectDownInSpace, StateDraggingSpace:
      self.selectBox = (0,0,0,0)
      self.mouseData.state = StateNone
    self.invalidate()
  of CmdSelectAll:
    self.selected.setAll(self.doc.db)
    self.resetMouseData()
    self.selectBox = (0,0,0,0)
    self.invalidate()
  else:
    discard

proc processMouseMoveEvent*(self: Editor, event: MouseEvt) = 
  # Separate specific events (eg shft+LMB) from state changes
  # For example, StateSelectDownInComp should be renamed to
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
    wmp = event.pos.toWorld(vp)
  
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
    self.mouseData.lastPos = event.pos
    if self.evaluateHovering(event.pos):
      self.invalidate()
  of StateSelectDownInComp, StateDraggingComp:
    self.mouseData.state = StateDraggingComp
    let
      hitid = self.mouseData.clickHitId.get
      scale = self.doc.grid.recommendScale(event.shift)
      lastSnap: WPoint = self.mouseData.lastPos.toWorld(vp).snap(self.doc.grid, scale=scale)
      newSnap: WPoint = wmp.snap(self.doc.grid, scale=scale)
      delta: WPoint = newSnap - lastSnap
    if event.ctrl and hitid in self.selected[]:
      # Group move should snap by grid amount even if not on grid to start
      self.moveRectsBy(self.selected[].toSeq, delta)
    else: # Snap pos to nearest grid point
      let newPos = (self.doc.db[hitid].pos + delta).snap(self.doc.grid, scale=scale)
      self.moveRectTo(hitid, newPos)
    self.mouseData.lastPos = event.pos
    self.invalidate()
  of StateSelectDownInSpace, StateDraggingSpace:
    # Collect items to be selected in tmpselect.
    # Only clear main selection if ctrl is not pressed.
    # Then copy tmp to main selection when mouse is released
    self.selectBox = pRect(self.mouseData.clickPos.get, event.pos)
    let selectRectW = wRect(self.mouseData.clickPos.get.toWorld(vp), wmp)
    let touchingCompsW = rectInComps(self.doc.db, selectRectW)
    if not event.ctrl:
      self.selected.clearAll()
    self.tmpSelected.clearAll()
    self.tmpSelected.setSome(touchingCompsW)
    self.mouseData.state = StateDraggingSpace
    self.invalidate()

proc processMouseButtonEvent*(self: Editor, event: MouseEvt) = 
  case self.mouseData.state
  of StateNone:
    if event.edge == mbeLeftDown:
      let
        hoveringComps = self.doc.db.ptInComps(event.pos, self.viewport)
        isHovering = hoveringComps.len > 0
        topComp = if isHovering: some(hoveringComps[^1])
                  else:          none(CompID)
      if event.edge == mbeLeftDown:
        self.mouseData.clickHitId = topComp
        self.mouseData.clickPos = some(event.pos)
        self.mouseData.state = if isHovering: StateSelectDownInComp
                               else:          StateSelectDownInSpace
  of StateSelectDownInComp:
    if event.edge == mbeLeftUp:
      let hitId = self.mouseData.clickHitId.get
      if event.ctrl:
        self.selected.toggleOne(hitId)
      else:
        let wasSelected = hitId in self.selected[]
        self.selected.clearAll()
        if not wasSelected:
          self.selected.toggleOne(hitId)
      self.resetMouseData()
      self.invalidate()
  of StateSelectDownInSpace:
    if event.edge == mbeLeftUp:
      self.resetMouseData()
      self.selected.clearAll()
      self.tmpSelected.clearAll()
      self.invalidate()
  of StateDraggingComp:
    if event.edge == mbeLeftUp:
      self.resetMouseData()
      self.selectBox = (0,0,0,0)
      self.invalidate()
  of StateDraggingSpace:
    if event.edge == mbeLeftUp:
      self.resetMouseData()
      self.selectBox = (0,0,0,0)
      self.selected.setSome(self.tmpSelected[].toSeq)
      self.invalidate()


proc processMouseWheelEvent*(self: Editor, event: MouseEvt) = 
  echo event
