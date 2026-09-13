import std/[sugar, strutils, strformat, parseutils]
import wNim, winim

import grid 
import routing
import utils
import uicommon
import wnimutils
import viewport

# Create a panel to hold some controls,
# then place it in a frame

type
  wGridControlPanel = ref object of wPanel
    grid*: Grid       # reference to the grid under control
    # Static Boxes
    sbInterval, sbBehavior, sbAppearance: wStaticBox

    # Static Texts
    stX, stY, stDivs, stDens: wStaticText

    # Text Controls
    txtX, txtY: wTextCtrl

    # Buttons
    bDone: wButton

    # Radio buttons
    rbDots, rbLines: wRadioButton

    # Checkboxes
    cbSnap, cbVisible, cbDynamic, cbBaseSync: wCheckBox

    # Other
    slDensity: wSlider
    cbDivisions: wComboBox

  wGridControlFrame* = ref object of wFrame
    mPanel: wGridControlPanel


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
    self.stX.position = (hmarg, vmarg)
    (l, r, t, b) = edges(self.stX)

    self.txtX.position = (r, vmarg)
    self.txtX.size = (spwidth, self.txtX.size.height)
    (l, r, t, b) = edges(self.txtX)

    self.stY.position = (r + hspc, vmarg)
    (l, r, t, b) = edges(self.stY)

    self.txtY.position = (r, vmarg)
    self.txtY.size = (spwidth, self.txtY.size.height)
    (l, r, t, b) = edges(self.txtY)

    self.stDivs.position = (r + hspc, vmarg)
    (l, r, t, b) = edges(self.stDivs)

    self.cbDivisions.position = (r, vmarg)
    self.cbDivisions.size = (spwidth, self.cbDivisions.size.height)
    (l, r, t, b) = edges(self.cbDivisions)

    self.stDens.position = (r + hspc, vmarg)
    (l, r, t, b) = edges(self.stDens)

    self.slDensity.position = (r, vmarg)
    self.slDensity.size = (spwidth, self.slDensity.size.height)

    self.sbInterval.contain(self.stX, self.txtX, self.stY, self.txtY,
                              self.stDivs, self.cbDivisions, self.stDens,
                              self.slDensity)
    (l, r, t, b) = edges(self.sbInterval)

    # Second box (second row)
    let secondrowtop = b + vspc
    self.cbSnap.position = (hmarg, secondrowtop)
    (_, r, t, _) = edges(self.cbSnap)

    self.cbDynamic.position = (r + hspc, secondrowtop)
    (l, r, t, b) = edges(self.cbDynamic)

    self.cbBaseSync.position = (r + hspc, secondrowtop)
    self.sbBehavior.contain(self.cbSnap, self.cbDynamic, self.cbBaseSync)
    (l, r, t, b) = edges(self.sbBehavior)

    # Third box (second row)
    self.cbVisible.position = (r + hspc + self.dpiScale(8), secondrowtop)
    (l, r, t, b) = edges(self.cbVisible)

    self.rbDots.position = (r + hspc, secondrowtop)
    (l, r, t, b) = edges(self.rbDots)

    self.rbLines.position = (r + hspc, secondrowtop)
    (l, r, t, b) = edges(self.rbLines)

    self.sbAppearance.contain(self.cbVisible, self.rbDots, self.rbLines)

    (l, r, t, b) = edges(self.sbAppearance)
    let rightmost = r

    # Done button
    self.bDone.position = (rightmost - buttWidth, b + vspc div 2 +
        self.dpiScale(8))
    self.bDone.size = (buttWidth, buttHeight)
    (l, r, t, b) = edges(self.bDone)

    # Minor text adjustments
    let vadj2 = self.dpiScale(0) #2
    self.stX.moveby(0, vadj2)
    self.stY.moveby(0, vadj2)
    self.stDivs.moveby(0, vadj2)
    self.stDens.moveby(0, vadj2)

    # Finalize frame size, then gray rectangle
    let (_, _, ibxt, _) = edges(self.sbInterval)
    let (_, _, _, abxb) = edges(self.bDone)
    let frameW = self.sbBehavior.size.width +
                 self.sbAppearance.size.width +
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
    dc.setBrush(Brush(gButtonAreaColor.wColor))
    dc.setPen(Pen(gButtonAreaColor.wColor))
    dc.drawRectangle(0, sz.height - barheight, sz.width, barheight)

  proc onDestroy(self: wGridControlPanel) =
    when defined(debug):
      echo "GridControlPanel onDestroy"
    self.deregisterListener()

  proc onButtonDone(self: wGridControlpanel) =
    # Post message for asynchronous close; otherwise if we do self.parent.close()
    # we get a synchronous close which destroys this button while still in the handler
    discard PostMessage(self.parent.handle, WM_CLOSE, 0, 0)


  proc eventMatchAndStrip(self: wGridControlPanel, event: wEvent): (wWindow, string) =
    let txtCtrls = [self.txtX, self.txtY]
    let comboBoxes = [self.cbDivisions]
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
    # So at no point is the self.cbDivisions.mHwnd used
    let (matchedCtrl, strval) = self.eventMatchAndStrip(event)
    if matchedCtrl.isnil or strval.len == 0:
      return
    if event.lParam == self.txtX.mHwnd or event.lParam ==
        self.txtY.mHwnd:
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
    if event.mOrigin == self.txtX.mHwnd:
      sendToListeners(idGCFRequestX, hi32.WPARAM, lo32.LPARAM)
    elif event.mOrigin == self.txtY.mHwnd:
      sendToListeners(idGCFRequestY, hi32.WPARAM, lo32.LPARAM)

  proc onCmdCbDivisionsSelect(self: wGridControlPanel, event: wEvent) =
    let index = self.cbDivisions.selection
    sendToListeners(idGCFDivisionsSelect, self.mHwnd.WPARAM, index.LPARAM)

  proc onCmdCbDivisionsTextEnter(self: wGridControlPanel, event: wEvent) =
    # Check if user-inputted text matches allowed divisions and send index if so
    # If not, then try to parse it as a number and send value
    let strval = self.cbDivisions.value
    var index = self.cbDivisions.findText(strval)
    if index >= 0:
      sendToListeners(idGCFDivisionsSelect, self.mHwnd.WPARAM, index.LPARAM)
    else:
      var val: int
      if parseNumber(strval, val):
        index = self.cbDivisions.findText($val)
        if index >= 0:
          # value found
          sendToListeners(idGCFDivisionsSelect, self.mHwnd.WPARAM, index.LPARAM)
        else:
          # value not found, clamp to within range
          let cval = clamp(val, DivRange.low, DivRange.high)
          sendToListeners(idGCFDivisionsValue, self.mHwnd.WPARAM, cval.LPARAM)
    # inputted value cannot be made into integer; don't send anything


  proc onCmdSliderDensity(self: wGridControlPanel, event: wEvent) =
    let finalval = self.slDensity.getValue()
    sendToListeners(idGCFDensity, self.mHWnd.WPARAM, finalval.LPARAM)
  #---
  proc onCmdSnap(self: wGridControlPanel, event: wEvent) =
    let state = self.cbSnap.value
    sendToListeners(idGCFSnap, self.mHwnd, state.LPARAM)
  proc onCmdDynamic(self: wGridControlPanel, event: wEvent) =
    let state = self.cbDynamic.value
    sendToListeners(idGCFDynamic, self.mHwnd, state.LPARAM)
  proc onCmdGridBaseSync(self: wGridControlPanel, event: wEvent) =
    let state = self.cbBaseSync.value
    sendToListeners(idGCFBaseSync, self.mHwnd, state.LPARAM)
  #--
  proc onCmdGridVisible(self: wGridControlPanel, event: wEvent) =
    let state = self.cbVisible.value
    sendToListeners(idGCFVisible, self.mHwnd, state.LPARAM)
  proc onCmdDots(self: wGridControlPanel, event: wEvent) =
    let state = self.rbDots.value
    sendToListeners(idGCFDots, self.mHwnd, state.LPARAM)
  proc onCmdLines(self: wGridControlPanel, event: wEvent) =
    let state = self.rbLines.value
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
      self.txtX.setValue(rxstr)
    elif event.mMsg == idGCFSizeY:
      self.txtY.setValue(rxstr)
  proc onGCFDivisionsSelect(self: wGridControlPanel, event: wEvent) =
    self.cbDivisions.select(event.lParam)
  proc onGCFDivisionsValue(self: wGridControlPanel, event: wEvent) =
    self.cbDivisions.setValue($event.lParam)
  proc onGCFDivisionsReset(self: wGridControlPanel, event: wEvent) =
    # Change divisions drop down options, sent after a
    # change in sizeX or sizeY. Current divisions setting is
    # not changed.  If current divisions setting is in allowed
    # divisions, then selected index is updated to use this value.

    self.cbDivisions.clear()
    for s in self.grid.allowedDivisionsStr:
      self.cbDivisions.append(s)

    let oldval = self.grid.divisions
    let newidx = self.cbDivisions.findText($oldval)
    if newidx >= 0:
      sendToListeners(idGCFDivisionsSelect, self.mHwnd.WPARAM, newidx.LPARAM)
    else:
      sendToListeners(idGCFDivisionsValue, self.mHwnd.WPARAM, oldval.LPARAM)

  proc onGCFDensity(self: wGridControlPanel, event: wEvent) =
    self.slDensity.setValue(event.lParam)
  #--
  proc onGCFSnap(self: wGridControlPanel, event: wEvent) =
    self.cbSnap.value = event.lParam.bool
  proc onGCFDynamic(self: wGridControlPanel, event: wEvent) =
    self.cbDynamic.value = event.lParam.bool
  proc onGCFBaseSync(self: wGridControlPanel, event: wEvent) =
    self.cbBaseSync.value = event.lParam.bool
  #--
  proc onGCFVisible(self: wGridControlPanel, event: wEvent) =
    let state = event.lParam.bool
    self.cbVisible.value = state
    self.rbDots.enable(state)
    self.rbLines.enable(state)
  proc onGCFDots(self: wGridControlPanel, event: wEvent) =
    self.rbDots.value = event.lParam.bool
    self.rbLines.value = not event.lParam.bool
  proc onGCFLines(self: wGridControlPanel, event: wEvent) =
    self.rbLines.value = event.lParam.bool
    self.rbDots.value = not event.lParam.bool
  proc onGCFZoom(self: wGridControlPanel, event: wEvent) =
    let md = self.grid.minDelta(Major)
    self.txtX.setValue($md.x)
    self.txtY.setValue($md.y)

  proc updateValues(self: wGridControlPanel) =
    self.txtX.setValue($self.grid.minDelta(Major).x)
    self.txtY.setValue($self.grid.minDelta(Major).y)
    self.cbDivisions.select(self.grid.divisionsIndex)
    self.slDensity.setValue((self.grid.mZctrl.density * 100.0).int)
    self.slDensity.setRange(10 .. 200) # from .1 to 2.0
    self.cbSnap.setValue(self.grid.mSnap)
    self.cbVisible.setValue(self.grid.mVisible)
    self.cbDynamic.setValue(self.grid.mZctrl.dynamic)
    self.cbBaseSync.setValue(self.grid.mZctrl.baseSync)
    self.rbDots.setValue(self.grid.mDotsOrLines == Dots)
    self.rbLines.setValue(self.grid.mDotsOrLines == Lines)

  proc init*(self: wGridControlPanel, parent: wWindow, gr: Grid) =
    wPanel(self).init(parent)
    self.backgroundColor = gPanelBackgroundColor
    self.grid = gr
    
    block: # Priming cache
      discard

    block: # Create controls
      # Static Boxes
      self.sbInterval   = StaticBox(self, label="Interval")
      self.sbBehavior   = StaticBox(self, label="Behavior")
      self.sbAppearance = StaticBox(self, label="Appearance")

      # Static Texts
      self.stX    = StaticText(self, label="X")
      self.stY    = StaticText(self, label="Y")
      self.stDivs = StaticText(self, label="Divisions")
      self.stDens = StaticText(self, label="Magnification")

      # Text Controls
      self.txtX = TextCtrl(self, style=wBorderStatic)
      self.txtY = TextCtrl(self, style=wBorderStatic)

      # Buttons
      self.bDone = Button(self, label="Done")

      # Radio Buttons
      self.rbDots  = RadioButton(self, label="Dots")
      self.rbLines = RadioButton(self, label="Lines")

      # Slider
      self.slDensity = Slider(self)

      # Checkboxes
      self.cbSnap     = CheckBox(self, label="Snap")
      self.cbVisible  = CheckBox(self, label="Visible")
      self.cbDynamic  = CheckBox(self, label="Dynamic")
      self.cbBaseSync = CheckBox(self, label="Cool zoom")

      # Combo boxes
      self.cbDivisions = ComboBox(self) #, choices = gr.allowedDivisionsStr)

    block: # Configure fonts
      discard

    block: # Respond to generic events
      self.wEvent_Size do (event: wEvent): self.onResize()
      self.wEvent_Paint do (event: wEvent): self.onPaint(event)
      self.wEvent_Destroy do(): self.onDestroy()

    block: # Respond to controls events
      self.WM_CTLCOLOREDIT do (event: wEvent): self.colorEdit(event)
      self.txtX.wEvent_TextEnter        do(event: wEvent): self.onCmdTxtSizeEnter(event)
      self.txtY.wEvent_TextEnter        do(event: wEvent): self.onCmdTxtSizeEnter(event)
      self.cbDivisions.wEvent_ComboBox  do(event: wEvent): self.onCmdCbDivisionsSelect(event)
      self.cbDivisions.wEvent_TextEnter do(event: wEvent): self.onCmdCbDivisionsTextEnter(event)
      self.slDensity.wEvent_Slider      do(event: wEvent): self.onCmdSliderDensity(event)
      self.cbSnap.wEvent_CheckBox       do(event: wEvent): self.onCmdSnap(event)
      self.cbDynamic.wEvent_CheckBox    do(event: wEvent): self.onCmdDynamic(event)
      self.cbBaseSync.wEvent_CheckBox   do(event: wEvent): self.onCmdGridBaseSync(event)
      self.cbVisible.wEvent_CheckBox    do(event: wEvent): self.onCmdGridVisible(event)
      self.rbDots.wEvent_RadioButton    do(event: wEvent): self.onCmdDots(event)
      self.rblines.wEvent_RadioButton   do(event: wEvent): self.onCmdLines(event)
      self.bDone.wEvent_Button          do(): self.onButtonDone()

    block: # Update controls from outside messages
      self.registerListener(idGCFSizeX,           (w: wWindow, e: wEvent)=>(onGCFSize(w.wGridControlPanel, e)))
      self.registerListener(idGCFSizeY,           (w: wWindow, e: wEvent)=>(onGCFSize(w.wGridControlPanel, e)))
      self.registerListener(idGCFDivisionsSelect, (w: wWindow, e: wEvent)=>(onGCFDivisionsSelect(w.wGridControlPanel, e)))
      self.registerListener(idGCFDivisionsValue,  (w: wWindow, e: wEvent)=>(onGCFDivisionsValue(w.wGridControlPanel, e)))
      self.registerListener(idGCFDivisionsReset,  (w: wWindow, e: wEvent)=>(onGCFDivisionsReset(w.wGridControlPanel, e)))
      self.registerListener(idGCFDensity,         (w: wWindow, e: wEvent)=>(onGCFDensity(w.wGridControlPanel, e)))
      self.registerListener(idGCFSnap,            (w: wWindow, e: wEvent)=>(onGCFSnap(w.wGridControlPanel, e)))
      self.registerListener(idGCFDynamic,         (w: wWindow, e: wEvent)=>(onGCFDynamic(w.wGridControlPanel, e)))
      self.registerListener(idGCFBaseSync,        (w: wWindow, e: wEvent)=>(onGCFBaseSync(w.wGridControlPanel, e)))
      self.registerListener(idGCFVisible,         (w: wWindow, e: wEvent)=>(onGCFVisible(w.wGridControlPanel, e)))
      self.registerListener(idGCFDots,            (w: wWindow, e: wEvent)=>(onGCFDots(w.wGridControlPanel, e)))
      self.registerListener(idGCFLines,           (w: wWindow, e: wEvent)=>(onGCFLines(w.wGridControlPanel, e)))
      self.registerListener(idGCFZoom,            (w: wWindow, e: wEvent)=>(onGCFZoom(w.wGridControlPanel, e)))

    block: # Initial values
      if not self.grid.isnil:
        self.updateValues()

    

wClass(wGridControlFrame of wFrame):
  proc setGrid*(self: wGridControlFrame, grid: Grid) =
    self.mPanel.grid = grid
    self.mPanel.updateValues()

  proc onClose(self: wGridControlFrame, event: wEvent) =
    # You can logic or check to event.veto() to 
    # stop the frame from closing and cascading
    # onDestroys down the tree
    # event.skip will override the veto(), but that's dumb
    # so don't use it
    when defined(debug):
      echo "GridControlFrame onClose; hiding"
    self.hide()
    event.veto()

  proc onDestroy(self: wGridControlFrame) =
    # event.veto doesn't do anything here
    # Do cleanup and announcements here
    when defined(debug):
      echo "GridControlFrame onDestroy; sending idGCFDestroying"
    sendToListeners(idGCFDestroying, self.mHwnd.WPARAM, 0)

  proc init*(self: wGridControlFrame, owner: wWindow, gr: Grid=nil) =
    let
      sz: wSize = (self.dpiScale(450), self.dpiScale(240))
      style=wModalFrame
    wFrame(self).init(owner, title = "Grid Settings", size=sz) #, style=style)
    self.backgroundColor = gFrameBackgroundColor
    self.mPanel = GridControlPanel(self, gr)
    self.mPanel.layout()
    # Respond to generic events
    self.wEvent_Close do(event: wEvent): self.onClose(event)
    self.wEvent_Destroy do(): self.onDestroy()

type
  wDummyFrame = ref object of wFrame
    gcf1: wGridControlFrame

wClass(wDummyFrame of wFrame):
  proc init(self: wDummyFrame) =
    wFrame(self).init(nil, title="Fake application frame")
    let
      zc = newZoomCtrl(base = 5, clickDiv = 2400, maxPwr = 5,
                    density = 1.0, dynamic = true, baseSync = true)
      gr = newGrid(zc) # requires appinit.json
      goButton = Button(self, label="Press me")
    self.gcf1 = GridControlFrame(self, gr)
    goButton.wEvent_Button do(): self.gcf1.show()

when isMainModule:
    # TODO: for any module that requires appinit internaly,
    # TODO: just make it load appinit as needed
  import jsoninit
  
  try:
    jsonInitGlobals()
    wSetSystemDPIAware()
    let
      app = App()
      appFrame = DummyFrame()
    appFrame.show()
    app.mainLoop()
  except Exception as e:
    echo e.msg
    echo e.getStackTrace()
