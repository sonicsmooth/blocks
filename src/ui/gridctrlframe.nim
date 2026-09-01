import std/[sugar, strutils, strformat, parseutils]
import wNim, winim

import grid 
import routing
import utils
import wnimutils
import viewport

# Create a panel to hold some controls,
# then place it in a frame

type
  #SpDensity* = distinct int
  CtrlID = enum
    # TODO: are these ids needed?
    idSpaceX = wIdUser, idSpaceY, idDivisions, idDensity,
    idSnap, idDynamic, idBaseSync,
    idVisible, idDots, idLines, idDone
  wGridControlPanel = ref object of wPanel
    grid: Grid       # reference to the grid under control
    mZctrl: ZoomCtrl # reference to params for grid zoom control
    mBDone: wButton
    mIntervalBox: wStaticbox
    mBehaviorBox: wStaticBox
    mAppearanceBox: wStaticBox
    txtX: wStaticText
    txtY: wStaticText
    txtDivs: wStaticText
    txtDens: wStaticText
    mCbSnap: wCheckBox
    mCbVisible: wCheckBox
    mCbDynamic: wCheckBox
    mCbBaseSync: wCheckBox
    mRbDots: wRadioButton
    mRbLines: wRadioButton
    txtSizeX: wTextCtrl
    txtSizeY: wTextCtrl
    mCbDivisions: wComboBox
    mSliderDensity: wSlider
  wGridControlFrame* = ref object of wFrame
    mPanel: wGridControlPanel

const
  frameBackgroundColor = 0xf0f0f0
  panelBackgroundColor = 0xf9f9f9
  buttonAreaColor = 0xf0f0f0

#var gFrameShowing: bool

proc edges(w: wWindow): tuple[left, right, top, bot: int] =
  (left: w.position.x,
    right: w.position.x + w.size.width,
    top: w.position.y,
    bot: w.position.y + w.size.height)

proc moveby(w: wWindow, dx, dy: int) =
  w.position = (w.position.x + dx, w.position.y + dy)

# TODO: "123abc" is not colored red and it should be like "abc"

proc errcol(event: wEvent) =
  SetBkColor(event.wParam, RGB(255, 199, 206))
  SetTextColor(event.wParam, RGB(156, 0, 6))


wClass(wGridControlPanel of wPanel):
  proc layout(self: wGridControlPanel) =
    let
      hmarg = self.parent.margin.left + self.dpiScale(8)
      vmarg = self.parent.margin.up + self.dpiscale(24)
      hspc = self.dpiScale(16)
      vspc = self.dpiScale(24)
      spwidth = self.dpiScale(60)
      buttWidth = self.dpiScale(120)
      buttHeight = self.dpiScale(30)
    var t, b, l, r: int

    # TODO: investigate using setBuddy

    # First row
    self.txtX.position = (hmarg, vmarg)
    (l, r, t, b) = edges(self.txtX)

    self.txtSizeX.position = (r, vmarg)
    self.txtSizeX.size = (spwidth, self.txtSizeX.size.height)
    (l, r, t, b) = edges(self.txtSizeX)

    self.txtY.position = (r + hspc, vmarg)
    (l, r, t, b) = edges(self.txtY)

    self.txtSizeY.position = (r, vmarg)
    self.txtSizeY.size = (spwidth, self.txtSizeY.size.height)
    (l, r, t, b) = edges(self.txtSizeY)

    self.txtDivs.position = (r + hspc, vmarg)
    (l, r, t, b) = edges(self.txtDivs)

    self.mCbDivisions.position = (r, vmarg)
    self.mCbDivisions.size = (spwidth, self.mCbDivisions.size.height)
    (l, r, t, b) = edges(self.mCbDivisions)

    self.txtDens.position = (r + hspc, vmarg)
    (l, r, t, b) = edges(self.txtDens)

    self.mSliderDensity.position = (r, vmarg)
    self.mSliderDensity.size = (spwidth, self.mSliderDensity.size.height)

    self.mIntervalBox.contain(self.txtX, self.txtSizeX, self.txtY, self.txtSizeY,
                              self.txtDivs, self.mCbDivisions, self.txtDens,
                              self.mSliderDensity)
    (l, r, t, b) = edges(self.mIntervalBox)

    # Second box (second row)
    let secondrowtop = b + vspc
    self.mCbSnap.position = (hmarg, secondrowtop)
    (_, r, t, _) = edges(self.mCbSnap)

    self.mCbDynamic.position = (r + hspc, secondrowtop)
    (l, r, t, b) = edges(self.mCbDynamic)

    self.mCbBaseSync.position = (r + hspc, secondrowtop)
    self.mBehaviorBox.contain(self.mCbSnap, self.mCbDynamic, self.mCbBaseSync)
    (l, r, t, b) = edges(self.mBehaviorBox)

    # Third box (second row)
    self.mCbVisible.position = (r + hspc + self.dpiScale(8), secondrowtop)
    (l, r, t, b) = edges(self.mCbVisible)

    self.mRbDots.position = (r + hspc, secondrowtop)
    (l, r, t, b) = edges(self.mRbDots)

    self.mRbLines.position = (r + hspc, secondrowtop)
    (l, r, t, b) = edges(self.mRbLines)

    self.mAppearanceBox.contain(self.mCbVisible, self.mRbDots, self.mRbLines)

    (l, r, t, b) = edges(self.mAppearanceBox)
    let rightmost = r

    # Done button
    self.mBDone.position = (rightmost - buttWidth, b + vspc div 2 +
        self.dpiScale(8))
    self.mBDone.size = (buttWidth, buttHeight)
    (l, r, t, b) = edges(self.mBDone)

    # Minor text adjustments
    let vadj2 = self.dpiScale(0) #2
    self.txtX.moveby(0, vadj2)
    self.txtY.moveby(0, vadj2)
    self.txtDivs.moveby(0, vadj2)
    self.txtDens.moveby(0, vadj2)

    # Finalize frame size, then gray rectangle
    let (_, _, ibxt, _) = edges(self.mIntervalBox)
    let (_, _, _, abxb) = edges(self.mBDone)
    let frameW = self.mBehaviorBox.size.width +
                 self.mAppearanceBox.size.width +
                 hspc + 2 * hmarg + self.dpiScale(6)
    let frameH = abxb - ibxt + self.parent.margin.up + self.parent.margin.down +
        self.dpiScale(58)
    self.parent.size = (frameW, frameH)

  proc onResize(self: wGridControlPanel) =
    self.layout()

  proc onPaint(self: wGridControlPanel, event: wEvent) =
    var dc = PaintDC(self)
    let
      sz = self.size
      buttHeight = self.dpiScale(24)
      barheight = buttHeight + self.dpiScale(28)

    # Rectangle behind button
    dc.setBrush(Brush(buttonAreaColor.wColor))
    dc.setPen(Pen(buttonAreaColor.wColor))
    dc.drawRectangle(0, sz.height - barheight, sz.width, barheight)

  proc eventMatchAndStrip(self: wGridControlPanel, event: wEvent): (wWindow, string) =
    let txtCtrls = [self.txtSizeX, self.txtSizeY]
    let comboBoxes = [self.mCbDivisions]
    for w in txtCtrls:
      if event.lParam == w.mHwnd or event.mOrigin == w.mHwnd:
        return (w, w.value.strip())
    for w in comboBoxes:
      if event.lparam == WindowFromDC(event.wParam):
        return (w, w.value.strip())

  proc colorEdit(self: wGridControlPanel, event: wEvent) =
    # Gets called when parent panel redraws text box
    # which is on mouse enter/leave, and when typing
    # but not on enter key.  For some reason when typing
    # in the divisions box, the lparam does not match
    # the mHwnd of the division box, but it does on mouse
    # enter/leave.  Instead, when typing in the divisions
    # box, the lparam matches the WindowFromDC of the wParam.
    # So at no point is the self.mCbDivisions.mHwnd used
    let (matchedCtrl, strval) = self.eventMatchAndStrip(event)
    if matchedCtrl.isnil or strval.len == 0:
      return
    if event.lParam == self.txtSizeX.mHwnd or event.lParam ==
        self.txtSizeY.mHwnd:
      var val: WType
      if not parseNumber(strval, val):
        errcol(event)
    elif event.lParam == WindowFromDC(event.wParam):
      # We are in the divisions combo box, so must use int
      var val: int
      if not parseNumber(strval, val):
        errcol(event)


  # Read state from controls and broadcast message to listeners
  # TODO: small txt units
  proc onCmdTxtSizeEnter(self: wGridControlPanel, event: wEvent) =
    # Called when enter pressed
    # send pointer to parsed and validated value
    let (matchedCtrl, strval) = self.eventMatchAndStrip(event)
    if matchedCtrl.isnil or strval.len == 0:
      return
    var val: Wtype
    if not parseNumber(strval, val):
      return
    let
      valptr = cast[uint64](val.addr)
      hi32 = (valptr shr 32).uint32
      lo32 = (valptr and 0xffff_ffff'u64).uint32
    if event.mOrigin == self.txtSizeX.mHwnd:
      sendToListeners(idGCFRequestX, hi32.WPARAM, lo32.LPARAM)
    elif event.mOrigin == self.txtSizeY.mHwnd:
      sendToListeners(idGCFRequestY, hi32.WPARAM, lo32.LPARAM)

  proc onCmdCbDivisionsSelect(self: wGridControlPanel, event: wEvent) =
    let index = self.mCbDivisions.selection
    sendToListeners(idGCFDivisionsSelect, self.mHwnd.WPARAM, index.LPARAM)

  proc onCmdCbDivisionsTextEnter(self: wGridControlPanel, event: wEvent) =
    # Check if user-inputted text matches allowed divisions and send index if so
    # If not, then try to parse it as a number and send value
    let strval = self.mCbDivisions.value
    var index = self.mCbDivisions.findText(strval)
    if index >= 0:
      sendToListeners(idGCFDivisionsSelect, self.mHwnd.WPARAM, index.LPARAM)
    else:
      var val: int
      if parseNumber(strval, val):
        index = self.mCbDivisions.findText($val)
        if index >= 0:
          # value found
          sendToListeners(idGCFDivisionsSelect, self.mHwnd.WPARAM, index.LPARAM)
        else:
          # value not found, clamp to within range
          let cval = clamp(val, DivRange.low, DivRange.high)
          sendToListeners(idGCFDivisionsValue, self.mHwnd.WPARAM, cval.LPARAM)
    # inputted value cannot be made into integer; don't send anything


  proc onCmdSliderDensity(self: wGridControlPanel, event: wEvent) =
    let finalval = self.mSliderDensity.getValue()
    sendToListeners(idGCFDensity, self.mHWnd.WPARAM, finalval.LPARAM)
  #---
  proc onCmdSnap(self: wGridControlPanel, event: wEvent) =
    let state = self.mCbSnap.value
    sendToListeners(idGCFSnap, self.mHwnd, state.LPARAM)
  proc onCmdDynamic(self: wGridControlPanel, event: wEvent) =
    let state = self.mCbDynamic.value
    sendToListeners(idGCFDynamic, self.mHwnd, state.LPARAM)
  proc onCmdGridBaseSync(self: wGridControlPanel, event: wEvent) =
    let state = self.mCbBaseSync.value
    sendToListeners(idGCFBaseSync, self.mHwnd, state.LPARAM)
  #--
  proc onCmdGridVisible(self: wGridControlPanel, event: wEvent) =
    let state = self.mCbVisible.value
    sendToListeners(idGCFVisible, self.mHwnd, state.LPARAM)
  proc onCmdDots(self: wGridControlPanel, event: wEvent) =
    let state = self.mRbDots.value
    sendToListeners(idGCFDots, self.mHwnd, state.LPARAM)
  proc onCmdLines(self: wGridControlPanel, event: wEvent) =
    let state = self.mRbLines.value
    sendToListeners(idGCFLines, self.mHwnd, state.LPARAM)

  # Respond to incoming messages, including from self
  # Update local UI only.  Don't do anything else.
  proc onGCFSize(self: wGridControlPanel, event: wEvent) =
    # We receive a pointer-to-float and display it
    let val = derefAs[WType](event)
    when WType is SomeFloat:
      let rxstr = &"{val:g}"
    elif WType is SomeInteger:
      let rxstr = $val
    if event.mMsg == idGCFSizeX:
      self.txtSizeX.setValue(rxstr)
    elif event.mMsg == idGCFSizeY:
      self.txtSizeY.setValue(rxstr)
  proc onGCFDivisionsSelect(self: wGridControlPanel, event: wEvent) =
    self.mCbDivisions.select(event.lParam)
  proc onGCFDivisionsValue(self: wGridControlPanel, event: wEvent) =
    self.mCbDivisions.setValue($event.lParam)
  proc onGCFDivisionsReset(self: wGridControlPanel, event: wEvent) =
    # Change divisions drop down options, sent after a
    # change in sizeX or sizeY. Current divisions setting is
    # not changed.  If current divisions setting is in allowed
    # divisions, then selected index is updated to use this value.

    self.mCbDivisions.clear()
    for s in self.grid.allowedDivisionsStr:
      self.mCbDivisions.append(s)

    let oldval = self.grid.divisions
    let newidx = self.mCbDivisions.findText($oldval)
    if newidx >= 0:
      sendToListeners(idGCFDivisionsSelect, self.mHwnd.WPARAM, newidx.LPARAM)
    else:
      sendToListeners(idGCFDivisionsValue, self.mHwnd.WPARAM, oldval.LPARAM)

  proc onGCFDensity(self: wGridControlPanel, event: wEvent) =
    self.mSliderDensity.setValue(event.lParam)
  #--
  proc onGCFSnap(self: wGridControlPanel, event: wEvent) =
    self.mCbSnap.value = event.lParam.bool
  proc onGCFDynamic(self: wGridControlPanel, event: wEvent) =
    self.mCbDynamic.value = event.lParam.bool
  proc onGCFBaseSync(self: wGridControlPanel, event: wEvent) =
    self.mCbBaseSync.value = event.lParam.bool
  #--
  proc onGCFVisible(self: wGridControlPanel, event: wEvent) =
    let state = event.lParam.bool
    self.mCbVisible.value = state
    self.mRbDots.enable(state)
    self.mRbLines.enable(state)
  proc onGCFDots(self: wGridControlPanel, event: wEvent) =
    self.mRbDots.value = event.lParam.bool
    self.mRbLines.value = not event.lParam.bool
  proc onGCFLines(self: wGridControlPanel, event: wEvent) =
    self.mRbLines.value = event.lParam.bool
    self.mRbDots.value = not event.lParam.bool
  proc onGCFZoom(self: wGridControlPanel, event: wEvent) =
    let md = self.grid.minDelta(Major)
    self.txtSizeX.setValue($md.x)
    self.txtSizeY.setValue($md.y)


  proc init*(self: wGridControlPanel, parent: wWindow, gr: Grid) =
    wPanel(self).init(parent)
    self.backgroundColor = panelBackgroundColor
    # Create controls
    self.grid = gr
    self.mZctrl = gr.mZctrl
    self.mBDone = Button(self, idDone, "Done")
    self.mIntervalBox = StaticBox(self, label = "Interval")
    self.mBehaviorBox = StaticBox(self, label = "Behavior")
    self.mAppearanceBox = StaticBox(self, label = "Appearance")

    self.txtX = StaticText(self, label = "X")
    self.txtY = StaticText(self, label = "Y")
    self.txtDivs = StaticText(self, label = "Divisions")
    self.txtDens = StaticText(self, label = "Magnification")
    self.txtSizeX = TextCtrl(self, idSpaceX, style = wBorderStatic)
    self.txtSizeY = TextCtrl(self, idSpaceY, style = wBorderStatic)
    self.mCbDivisions = ComboBox(self, idDivisions,
        choices = gr.allowedDivisionsStr)
    self.mSliderDensity = Slider(self, idDensity)
    self.mCbSnap = CheckBox(self, idSnap, "Snap")
    self.mCbVisible = CheckBox(self, idVisible, "Visible")
    self.mCbDynamic = CheckBox(self, idDynamic, "Dynamic")
    self.mCbBaseSync = CheckBox(self, idBaseSync, "Cool zoom")
    self.mRbDots = RadioButton(self, idDots, "Dots")
    self.mRbLines = RadioButton(self, idLines, "Lines")


    self.txtSizeX.setValue($self.grid.minDelta(Major).x)
    self.txtSizeY.setValue($self.grid.minDelta(Major).y)
    self.mCbDivisions.select(self.grid.divisionsIndex)
    self.mSliderDensity.setValue((self.mZctrl.density * 100.0).int)
    self.mSliderDensity.setRange(10 .. 200) # from .1 to 2.0
    self.mCbSnap.setValue(self.grid.mSnap)
    self.mCbVisible.setValue(self.grid.mVisible)
    self.mCbDynamic.setValue(self.grid.mZctrl.dynamic)
    self.mCbBaseSync.setValue(self.grid.mZctrl.baseSync)
    self.mRbDots.setValue(self.grid.mDotsOrLines == Dots)
    self.mRbLines.setValue(self.grid.mDotsOrLines == Lines)

    self.layout()

    # Respond to generic events
    self.wEvent_Size do (event: wEvent): self.onResize()
    self.wEvent_Paint do (event: wEvent): self.onPaint(event)

    # Respond to controls
    self.WM_CTLCOLOREDIT do (event: wEvent): self.colorEdit(event)
    self.txtSizeX.wEvent_TextEnter do (event: wEvent): self.onCmdTxtSizeEnter(event)
    self.txtSizeY.wEvent_TextEnter do (event: wEvent): self.onCmdTxtSizeEnter(event)
    self.mCbDivisions.wEvent_ComboBox do (
      event: wEvent): self.onCmdCbDivisionsSelect(event)
    self.mCbDivisions.wEvent_TextEnter do (
      event: wEvent): self.onCmdCbDivisionsTextEnter(event)
    self.mSliderDensity.wEvent_Slider do (
      event: wEvent): self.onCmdSliderDensity(event)
    #--
    self.mCbSnap.wEvent_CheckBox do (event: wEvent): self.onCmdSnap(event)
    self.mCbDynamic.wEvent_CheckBox do (event: wEvent): self.onCmdDynamic(event)
    self.mCbBaseSync.wEvent_CheckBox do (event: wEvent): self.onCmdGridBaseSync(event)
    #--
    self.mCbVisible.wEvent_CheckBox do (event: wEvent): self.onCmdGridVisible(event)
    self.mRbDots.wEvent_RadioButton do (event: wEvent): self.onCmdDots(event)
    self.mRblines.wEvent_RadioButton do (event: wEvent): self.onCmdLines(event)

    # Update controls from outside messages
    self.registerListener(idGCFSizeX, (w: wWindow, e: wEvent)=>(
        onidGCFSize(w.wGridControlPanel, e)))
    self.registerListener(idGCFSizeY, (w: wWindow, e: wEvent)=>(
        onidGCFSize(w.wGridControlPanel, e)))
    self.registerListener(idGCFDivisionsSelect, (w: wWindow, e: wEvent)=>(
        onidGCFDivisionsSelect(w.wGridControlPanel, e)))
    self.registerListener(idGCFDivisionsValue, (w: wWindow, e: wEvent)=>(
        onidGCFDivisionsValue(w.wGridControlPanel, e)))
    self.registerListener(idGCFDivisionsReset, (w: wWindow, e: wEvent)=>(
        onidGCFDivisionsReset(w.wGridControlPanel, e)))
    self.registerListener(idGCFDensity, (w: wWindow, e: wEvent)=>(
        onidGCFDensity(w.wGridControlPanel, e)))
    #--
    self.registerListener(idGCFSnap, (w: wWindow, e: wEvent)=>(
        onidGCFSnap(w.wGridControlPanel, e)))
    self.registerListener(idGCFDynamic, (w: wWindow, e: wEvent)=>(
        onidGCFDynamic(w.wGridControlPanel, e)))
    self.registerListener(idGCFBaseSync, (w: wWindow, e: wEvent)=>(
        onidGCFBaseSync(w.wGridControlPanel, e)))
    #--
    self.registerListener(idGCFVisible, (w: wWindow, e: wEvent)=>(
        onidGCFVisible(w.wGridControlPanel, e)))
    self.registerListener(idGCFDots, (w: wWindow, e: wEvent)=>(
        onidGCFDots(w.wGridControlPanel, e)))
    self.registerListener(idGCFLines, (w: wWindow, e: wEvent)=>(
        onidGCFLines(w.wGridControlPanel, e)))
    #--
    self.registerListener(idGCFZoom, (w: wWindow, e: wEvent)=>(
        onidGCFZoom(w.wGridControlPanel, e)))
    self.mBDone.wEvent_Button do(): self.parent.destroy()
    #self.wEvent_Destroy do(): self.deregisterListener()
    self.wEvent_Close do(): self.deregisterListener()

wClass(wGridControlFrame of wFrame):
  proc onDestroy(self: wGridControlFrame) =
    sendToListeners(idGCFCtrlFrameClosing, self.mHwnd.WPARAM, 0)

  proc init*(self: wGridControlFrame, owner: wWindow, gr: Grid) =
    let
      sz: wSize = (self.dpiScale(450), self.dpiScale(240))
      style = wModalFrame
    # TODO figure out why dpiscale returns 0
    wFrame(self).init(owner, title = "Grid Settings", size = sz, style = style)
    self.marginLeft = self.dpiScale(12)
    self.marginRight = self.dpiScale(12)
    self.marginUp = self.dpiScale(12)
    self.marginDown = self.dpiScale(0)
    self.backgroundColor = frameBackgroundColor
    self.mPanel = GridControlPanel(self, gr)
    self.wEvent_Close do(): self.onDestroy()

when isMainModule:
  import jsoninit
  try:
    jsonInitGlobals()
    wSetSystemDPIAware()
    let
      app = App()
      zc = newZoomCtrl(base = 5, clickDiv = 2400, maxPwr = 5,
                       density = 1.0, dynamic = true, baseSync = true)
      # TODO: for any module that requires appinit internaly,
      # TODO: just make it load appinit as needed
      gr = newGrid(zc) # requires appinit.json
      f1 = GridControlFrame(nil, gr)
    echo gr[]
    f1.show()
    app.mainLoop()
  except Exception as e:
    echo e.msg
    echo e.getStackTrace()
