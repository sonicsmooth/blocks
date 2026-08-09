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
#from utils import excl
import zoomctrl

type
  MouseEventKind* = enum mekNone, mekMove, mekDown, mekUp, mekDbl, 
                    mekWheelVert, mekWheelHoriz
  MouseButton* = enum mbNone, mbLeft, mbMid, mbRight
  MouseUpDown* = enum mbdirNone, mbDirUp, mbDirDown
  MouseEvt* = tuple
    pos: PxPoint
    kind: MouseEventKind
    btnLeft, btnMid, btnRight: bool # what is true immediately after event
    button: MouseButton # which button caused event
    edgeDir: MouseUpDown # which way it went
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
    StateSelectNone
    StateSelectDownInComp
    StateSelectDownInSpace
    StateSelectDraggingComp
    StateSelectDraggingSpace
  PanState = enum
    PanStateNone
    PanStateDown
    PanStateMoving
  MouseData = tuple
    clickHitId : Option[CompID]
    clickPos:    Option[PxPoint] # only used for select box
    lastPos:     PxPoint
    state:       MouseState
    panState:    PanState


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
    dirty*:        DirtySet
    groupRotation: bool # prevents deselection after rotation
    onZoomChanged*: proc() {.gcsafe.}
    invalidate*:    proc() {.gcsafe.}

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
  result.dirty = newDirtySet()

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
proc rotateRects(self: Editor, compIDs: seq[CompID], amt: Rotation) =
  # Rotate about each component's origin
  #self.dirty.setSome(compIDs)
  for id in compIDs:
    self.doc.db[id].rotate(amt)
proc rotateRects(self: Editor, compIDs: seq[CompID], amt: Rotation, pos: WPoint) =
  # Rotate about pos
  self.dirty.setSome(compIDs)
  for id in compIDs:
    self.doc.db[id].rotateAbout(amt, pos)
proc deleteRects(self: Editor, compIDs: seq[CompID]) =
  self.hovering.clearSome(compIDs)
  self.selected.clearSome(compIDs)
  self.dirty.clearSome(compIDs)
  for id in compIDs:
    self.doc.db.del(id) # Todo: check whether this deletes rect
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
  self.mouseData.state = StateSelectNone
  self.mouseData.panState = PanStateNone
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
  of CmdRotateCCW, CmdRotateCW, CmdRotateCCWAbout, CmdRotateCWAbout:
    var amt: Rotation
    case cmdTable[key]
    of CmdRotateCCW, CmdRotateCCWAbout: amt = R90
    of CmdRotateCW,  CmdRotateCWAbout:  amt = R270
    else: raise newException(ValueError, "Rotate cmd error")
    # Group rotate if mouse is pressed outside component,
    # otherwise individual rotation
    case self.mouseData.state
    of StateSelectNone:
      self.rotateRects(sel, amt)
    of StateSelectDownInComp:
      if sel.len == 0:
        self.rotateRects(@[self.mouseData.clickHitId.get], amt, wmp)
      else:
        self.rotateRects(sel, amt, wmp)
      self.groupRotation = true
    of StateSelectDraggingComp:
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
    of StateSelectDraggingSpace:
      self.selectBox = (0,0,0,0)
      self.mouseData.state = StateSelectNone
  of CmdSelectAll:
    self.selected.setAll(self.doc.db)
    self.resetMouseData()
    self.selectBox = (0,0,0,0)
  self.invalidate()

proc processMouseSelectMoveEvent*(self: Editor, event: MouseEvt) = 
  let 
    vp = self.viewport
    wmp = event.pos.toWorld(vp)
  case self.mouseData.state
  of StateSelectNone:
    if self.evaluateHovering(event.pos):
      self.invalidate()
  of StateSelectDownInComp, StateSelectDraggingComp:
    self.groupRotation = false
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
    self.mouseData.state = StateSelectDraggingComp
    self.invalidate()
  of StateSelectDownInSpace, StateSelectDraggingSpace:
    # Collect items to be selected in tmpselect.
    # Only clear main selection if ctrl is not pressed.
    # Then copy tmp to main selection when mouse is released
    self.groupRotation = false
    self.selectBox = pRect(self.mouseData.clickPos.get, event.pos)
    let selectRectW = wRect(self.mouseData.clickPos.get.toWorld(vp), wmp)
    let touchingCompsW = rectInComps(self.doc.db, selectRectW)
    if not event.ctrl:
      self.selected.clearAll()
    self.tmpSelected.clearAll()
    self.tmpSelected.setSome(touchingCompsW)
    self.mouseData.state = StateSelectDraggingSpace
    self.invalidate()

proc processMousePanMoveEvent*(self: Editor, event: MouseEvt) = 
  if self.mouseData.panState == PanStateDown or
     self.mouseData.panState == PanStateMoving:
    let deltaPx: PxPoint = (event.pos.x - self.mouseData.lastPos.x,
                            event.pos.y - self.mouseData.lastPos.y)
    self.viewport.doPan(deltaPx)
    self.mouseData.panState = PanStateMoving
    self.invalidate()

proc processMouseMoveEvent*(self: Editor, event: MouseEvt) =
  self.processMouseSelectMoveEvent(event)
  self.processMousePanMoveEvent(event)
  self.mouseData.lastPos = event.pos

proc processLeftMouseClickEvent*(self: Editor, event: MouseEvt) = 
  if event.edgeDir == mbDirDown:
    if self.mouseData.state == StateSelectNone:
      let
        hoveringComps = self.doc.db.ptInComps(event.pos, self.viewport)
        isHovering = hoveringComps.len > 0
        topComp = if isHovering: some(hoveringComps[^1])
                  else:          none(CompID)
      self.mouseData.clickHitId = topComp
      self.mouseData.clickPos = some(event.pos)
      self.mouseData.state = if isHovering: StateSelectDownInComp
                             else:          StateSelectDownInSpace
  elif event.edgeDir == mbDirUp:
    case self.mouseData.state
    of StateSelectDownInComp:
      let hitId = self.mouseData.clickHitId.get
      if event.ctrl:
        self.selected.toggleOne(hitId)
      else:
        if not self.groupRotation:
          let soloSel = self.selected[].len == 1 and hitId in self.selected[]
          self.selected.clearAll()
          if not soloSel:
            self.selected.toggleOne(hitId)
    of StateSelectDownInSpace:
      if not self.groupRotation:
        self.selected.clearAll()
        self.tmpSelected.clearAll()
    of StateSelectDraggingComp:
      discard
    of StateSelectDraggingSpace:
      self.selected.setSome(self.tmpSelected[].toSeq)
      self.tmpSelected.clearAll()
    else:
      discard
    self.selectBox = (0,0,0,0)
    self.invalidate()
    self.resetMouseData()

proc processMidMouseClickEvent*(self: Editor, event: MouseEvt) =
  if event.edgeDir == mbDirDown:
    echo "mid down"
  elif event.edgeDir == mbDirUp:
    echo "mid up"

proc processRightMouseClickEvent*(self: Editor, event: MouseEvt) =
  if event.edgeDir == mbDirDown:
    if self.mouseData.panState == PanStateNone:
      self.mouseData.panState = PanStateDown
  elif event.edgeDir == mbDirUp:
    self.mouseData.panState = PanStateNone

proc processMouseClickEvent*(self: Editor, event: MouseEvt) =
  case event.button
  of mbNone:  raise newException(ValueError, "Should not get mbNone here")
  of mbLeft:  self.processLeftMouseClickEvent(event)
  of mbMid:   self.processMidMouseClickEvent(event)
  of mbRight: self.processRightMouseClickEvent(event)

proc processMouseWheelEvent*(self: Editor, event: MouseEvt) = 
  self.viewport.doAdaptivePanZoom(event.wheelDelta, event.pos)
  #sendToListeners(idMsgGridZoom, 0, 0)
  self.dirty.setAll(self.doc.db)
  self.onZoomChanged()
  self.invalidate()
