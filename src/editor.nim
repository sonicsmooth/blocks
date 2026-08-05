import std/[options,
            sets, 
            sequtils]
import wNim
import appopts
import document
import pointmath
import rects
import reporting
import rotation
from utils import excl
import zoomctrl

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
    CmdRotateCCWAbout
    CmdRotateCW
    CmdRotateCWAbout
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
    tmpSelected:   SelectedSet # used during drag-select
    groupRotation: bool # prevents deselection after rotation
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
     (keyCode: KeySpace,  ctrl: true,  alt: false, shift: false ): CmdRotateCCWAbout,
     (keyCode: KeySpace,  ctrl: true,  alt: false, shift: true  ): CmdRotateCWAbout,
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
proc moveRectTo(self: Editor, compID: CompID, delta: WPoint) =
  # Common proc to move one or more Rects; used by mouse and keyboard
  moveRectTo(self.doc.db[compID], delta)
  self.invalidate()
proc rotateRects(self: Editor, compIDs: seq[CompID], amt: Rotation) =
  # Rotate about each component's origin
  for id in compIDs:
    self.doc.db[id].rotate(amt)
    ##!!!!!self.clearTextureCache(id)
  self.invalidate()
proc rotateRects(self: Editor, compIDs: seq[CompID], amt: Rotation, pos: WPoint) =
  # Rotate about pos
  for id in compIDs:
    self.doc.db[id].rotateAbout(amt, pos)
proc deleteRects(self: Editor, compIDs: seq[CompID]) =
  for id in compIDs:
    self.doc.db.del(id) # Todo: check whether this deletes rect
    ##!!!!!self.clearTextureCache(id)
  self.fillArea = self.doc.db.fillArea()
  self.invalidate()
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
  self.groupRotation= false


proc processKeyDown*(self: Editor, key: Key) =
  if key notin cmdTable:
    echo "Key not recognized"
    return
  let sel = self.selected.trueItems
  let wmp = self.mouseData.lastPos.toWorld(self.viewport)
  case cmdTable[key]:
  of CmdEscape:
    self.resetMouseData()
    self.selectBox = (0,0,0,0)
    self.tmpSelected.clearAll()
  of CmdMove:
    let
      sc = if key.shift: Tiny else: Minor
      md: WPoint = minDelta(self.doc.grid, scale=sc)
      moveby: WPoint = md .* moveTable[key.keyCode]
    self.moveRectsBy(sel, moveBy)
    self.resetMouseData()
    self.selectBox = (0,0,0,0)
  of CmdDelete:
    self.deleteRects(sel)
    self.resetMouseData()
    self.selectBox = (0,0,0,0)
  # TODO: implement group rotation
  of CmdRotateCCW, CmdRotateCW, CmdRotateCCWAbout, CmdRotateCWAbout:
    var amt: Rotation
    case cmdTable[key]
    of CmdRotateCCW, CmdRotateCCWAbout: amt = R90
    of CmdRotateCW,  CmdRotateCWAbout:  amt = R270
    else: raise newException(ValueError, "Rotate cmd error")
    # Group rotate if mouse is pressed outside component,
    # otherwise individual rotation
    case self.mouseData.state
    of StateNone:
      self.rotateRects(sel, amt)
    of StateSelectDownInComp:
      if sel.len == 0:
        self.rotateRects(@[self.mouseData.clickHitId.get], amt, wmp)
      else:
        self.rotateRects(sel, amt, wmp)
      self.groupRotation = true
    of StateDraggingComp:
      if sel.len == 0:
        self.rotateRects(@[self.mouseData.clickHitId.get], amt)
      else:
        if key.ctrl:
          self.rotateRects(@[self.mouseData.clickHitId.get], amt)
        else:
          if self.mouseData.clickHitId.get in sel:
            self.rotateRects(sel, amt, wmp)
          else:
            self.rotateRects(@[self.mouseData.clickHitId.get], amt)
    of StateSelectDownInSpace:
      self.rotateRects(sel, amt, wmp)
      self.groupRotation = true
    of StateDraggingSpace:
      self.selectBox = (0,0,0,0)
      self.mouseData.state = StateNone
  of CmdSelectAll:
    self.selected.setAll(self.doc.db)
    self.resetMouseData()
    self.selectBox = (0,0,0,0)
  self.invalidate()

proc processMouseMoveEvent*(self: Editor, event: MouseEvt) = 
 
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
    if not event.ctrl and hitid in self.selected[]:
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

proc procesMouseClickEvent*(self: Editor, event: MouseEvt) = 
  var doInvalidate = true
  var doResetMouseData = true
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
    doInvalidate = false
    doResetMouseData = false
  of StateSelectDownInComp:
    if event.edge == mbeLeftUp:
      let hitId = self.mouseData.clickHitId.get
      if event.ctrl:
        self.selected.toggleOne(hitId)
      else:
        if not self.groupRotation:
          if self.selected[].len > 0:
            self.selected.clearAll()
          self.selected.toggleOne(hitId)
  of StateSelectDownInSpace:
    if event.edge == mbeLeftUp:
      if not self.groupRotation:
        self.selected.clearAll()
        self.tmpSelected.clearAll()
  of StateDraggingComp:
    discard
  of StateDraggingSpace:
    if event.edge == mbeLeftUp:
      self.selected.setSome(self.tmpSelected[].toSeq)
      self.tmpSelected.clearAll()
  self.selectBox = (0,0,0,0)
  if doInvalidate: self.invalidate()
  if doResetMouseData: self.resetMouseData()

proc processMouseWheelEvent*(self: Editor, event: MouseEvt) = 
  when defined(debug):
    echo $self.selected[] & " " & $event
