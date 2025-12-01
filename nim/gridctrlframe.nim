import std/[math, sugar, strutils, strformat, parseutils]
import wNim, winim
import grid, viewport, utils
import routing

# Create a panel to hold some controls,
# then place it in a frame

type
  #SpDensity* = distinct int
  CtrlID = enum
    idSpaceX = wIdUser, idSpaceY, idDivisions, idDensity,
    idSnap, idDynamic, idBaseSync,
    idVisible, idDots, idLines, idDone
  wGridControlPanel = ref object of wPanel
    mGrid:          Grid     # reference to the grid under control
    mZctrl:         ZoomCtrl # reference to params for grid zoom control
    mBDone:         wButton
    mIntervalBox:   wStaticbox
    mBehaviorBox:   wStaticBox
    mAppearanceBox: wStaticBox
    mTxtX:          wStaticText
    mTxtY:          wStaticText
    mTxtDivs:       wStaticText
    mTxtDens:       wStaticText
    mCbSnap:        wCheckBox
    mCbVisible:     wCheckBox
    mCbDynamic:     wCheckBox
    mCbBaseSync:    wCheckBox
    mRbDots:        wRadioButton
    mRbLines:       wRadioButton
    mTxtSizeX:      wTextCtrl
    mTxtSizeY:      wTextCtrl
    mCbDivisions:   wComboBox
    mSliderDensity: wSlider
  wGridControlFrame* = ref object of wFrame
    mPanel: wGridControlPanel

const
  frameBackgroundColor = 0xf0f0f0
  panelBackgroundColor = 0xf9f9f9
  buttonAreaColor = 0xf0f0f0

var gFrameShowing: bool

proc edges(w: wWindow): tuple[left, right, top, bot: int] =
  (left:  w.position.x,
    right: w.position.x + w.size.width,
    top:   w.position.y,
    bot:   w.position.y + w.size.height)

proc moveby(w: wWindow, dx, dy: int) =
  w.position = (w.position.x + dx, w.position.y + dy)

proc parseNumber[T](s: string, number: var T): bool =
  # Returns true if s can be parsed to int or float
  # Parsed value is returned in val
  when T is SomeFloat:   parseFloat(s, number) > 0
  elif T is SomeInteger: parseInt(s, number) > 0
  else:
    static: echo "Unsupported WType in parseNumber"
    false

let errcol = proc(event: wEvent) =
    SetBkColor(event.wParam, RGB(255, 199, 206))
    SetTextColor(event.wParam, RGB(156, 0, 6))

let goodcol = proc(event: wEvent) =
    SetBkColor(event.wParam, RGB(0xc6, 0xef, 0xce)) #c6efce
    SetTextColor(event.wParam, RGB(0, 0x61, 0)) #006100


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
    self.mTxtX.position = (hmarg, vmarg)
    (l,r,t,b) = edges(self.mTxtX)

    self.mTxtSizeX.position = (r, vmarg)
    self.mTxtSizeX.size = (spwidth, self.mTxtSizeX.size.height)
    (l,r,t,b) = edges(self.mTxtSizeX)

    self.mTxtY.position = (r + hspc, vmarg)
    (l,r,t,b) = edges(self.mTxtY)

    self.mTxtSizeY.position = (r, vmarg)
    self.mTxtSizeY.size = (spwidth, self.mTxtSizeY.size.height)
    (l,r,t,b) = edges(self.mTxtSizeY)

    self.mTxtDivs.position = (r + hspc, vmarg)
    (l,r,t,b) = edges(self.mTxtDivs)

    self.mCbDivisions.position = (r, vmarg)
    self.mCbDivisions.size = (spwidth, self.mCbDivisions.size.height)
    (l,r,t,b) = edges(self.mCbDivisions)

    self.mTxtDens.position = (r + hspc, vmarg)
    (l,r,t,b) = edges(self.mTxtDens)

    self.mSliderDensity.position = (r, vmarg)
    self.mSliderDensity.size = (spwidth, self.mSliderDensity.size.height)

    self.mIntervalBox.contain(self.mTxtX, self.mTxtSizeX, self.mTxtY, self.mTxtSizeY,
                              self.mTxtDivs, self.mCbDivisions, self.mTxtDens, self.mSliderDensity)
    (l,r,t,b) = edges(self.mIntervalBox)

    # Second box (second row)
    let secondrowtop = b + vspc
    self.mCbSnap.position = (hmarg, secondrowtop)
    (_,r,t,_) = edges(self.mCbSnap)

    self.mCbDynamic.position = (r + hspc, secondrowtop)
    (l,r,t,b) = edges(self.mCbDynamic)

    self.mCbBaseSync.position = (r + hspc, secondrowtop)
    self.mBehaviorBox.contain(self.mCbSnap, self.mCbDynamic, self.mCbBaseSync)
    (l,r,t,b) = edges(self.mBehaviorBox)
    
    # Third box (second row)
    self.mCbVisible.position = (r + hspc + self.dpiScale(8), secondrowtop)
    (l,r,t,b) = edges(self.mCbVisible)

    self.mRbDots.position = (r + hspc, secondrowtop)
    (l,r,t,b) = edges(self.mRbDots)
    
    self.mRbLines.position = (r + hspc, secondrowtop)
    (l,r,t,b) = edges(self.mRbLines)

    self.mAppearanceBox.contain(self.mCbVisible, self.mRbDots, self.mRbLines)
    
    (l,r,t,b) = edges(self.mAppearanceBox)
    let rightmost = r

    # Done button
    self.mBDone.position = (rightmost - buttWidth, b + vspc div 2 + self.dpiScale(8))
    self.mBDone.size = (buttWidth, buttHeight)
    (l,r,t,b) = edges(self.mBDone)

    # Minor text adjustments
    let vadj2 = self.dpiScale(0) #2
    self.mTxtX.moveby(0, vadj2)
    self.mTxtY.moveby(0, vadj2)
    self.mTxtDivs.moveby(0, vadj2)
    self.mTxtDens.moveby(0, vadj2)

    # Finalize frame size, then gray rectangle
    let (_,_,ibxt,_) = edges(self.mIntervalBox)
    let (_,_,_,abxb) = edges(self.mBDone)
    let frameW = self.mBehaviorBox.size.width + 
                 self.mAppearanceBox.size.width + 
                 hspc + 2 * hmarg + self.dpiScale(6)
    let frameH = abxb - ibxt + self.parent.margin.up + self.parent.margin.down + self.dpiScale(58) 
    self.parent.size = (frameW, frameH)

  proc onResize(self: wGridControlPanel) =
    self.layout()

  proc onPaint(self: wGridControlPanel, event: wEvent) = 
    var dc = PaintDC(self)
    let
      sz = self.size
      buttHeight = self.dpiScale(24)
      barheight = buttHeight +  self.dpiScale(28)

    # Rectangle behind button
    dc.setBrush(Brush(buttonAreaColor.wColor))
    dc.setPen(Pen(buttonAreaColor.wColor))
    dc.drawRectangle(0, sz.height - barheight, sz.width, barheight)

  var cnt: int = 0
  proc eventMatchAndStrip(self: wGridControlPanel, event: wEvent): (wWindow, string) =
    let txtCtrls = [self.mTxtSizeX, self.mTxtSizeY]
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
    if event.lParam == self.mTxtSizeX.mHwnd or event.lParam == self.mTxtSizeY.mHwnd:
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
      hi32 =  (valptr shr 32).uint32
      lo32 = (valptr and 0xffff_ffff'u64).uint32
    if event.mOrigin == self.mTxtSizeX.mHwnd:
      sendToListeners(idMsgGridRequestX, hi32.WPARAM, lo32.LPARAM)
    elif event.mOrigin == self.mTxtSizeY.mHwnd:
      sendToListeners(idMsgGridRequestY, hi32.WPARAM, lo32.LPARAM)

  proc onCmdCbDivisionsSelect(self: wGridControlPanel, event: wEvent) =
    let index = self.mCbDivisions.selection
    sendToListeners(idMsgGridDivisionsSelect, self.mHwnd.WPARAM, index.LPARAM)

  proc onCmdCbDivisionsTextEnter(self: wGridControlPanel, event: wEvent) =
    # Check if user-inputted text matches allowed divisions and send index if so
    # If not, then try to parse it as a number and send value
    let strval  = self.mCbDivisions.value
    var index = self.mCbDivisions.findText(strval)
    if index >= 0:
      sendToListeners(idMsgGridDivisionsSelect, self.mHwnd.WPARAM, index.LPARAM)
    else:
      var val: int
      if parseNumber(strval, val):
        index = self.mCbDivisions.findText($val)
        if index >= 0:
          # value found
          sendToListeners(idMsgGridDivisionsSelect, self.mHwnd.WPARAM, index.LPARAM)
        else:
          # value not found, clamp to within range
          let cval = clamp(val, DivRange.low, DivRange.high)
          sendToListeners(idMsgGridDivisionsValue, self.mHwnd.WPARAM, cval.LPARAM)
    # inputted value cannot be made into integer; don't send anything


  proc onCmdSliderDensity(self: wGridControlPanel, event: wEvent) =
    let finalval = self.mSliderDensity.getValue()
    sendToListeners(idMsgGridDensity, self.mHWnd.WPARAM, finalval.LPARAM)
  #---
  proc onCmdSnap(self: wGridControlPanel, event: wEvent) =
    let state = self.mCbSnap.value
    sendToListeners(idMsgGridSnap, self.mHwnd, state.LPARAM)
  proc onCmdDynamic(self: wGridControlPanel, event: wEvent) =
    let state = self.mCbDynamic.value
    sendToListeners(idMsgGridDynamic, self.mHwnd, state.LPARAM)
  proc onCmdGridBaseSync(self: wGridControlPanel, event: wEvent) =
    let state = self.mCbBaseSync.value
    sendToListeners(idMsgGridBaseSync, self.mHwnd, state.LPARAM)
  #--
  proc onCmdGridVisible(self: wGridControlPanel, event: wEvent) =
    let state = self.mCbVisible.value
    sendToListeners(idMsgGridVisible, self.mHwnd, state.LPARAM)
  proc onCmdDots(self: wGridControlPanel, event: wEvent) =
    let state = self.mRbDots.value
    sendToListeners(idMsgGridDots, self.mHwnd, state.LPARAM)
  proc onCmdLines(self: wGridControlPanel, event: wEvent) =
    let state = self.mRbLines.value
    sendToListeners(idMsgGridLines, self.mHwnd, state.LPARAM)

  # Respond to incoming messages, including from self
  # Update local UI only.  Don't do anything else.
  proc onMsgGridSize(self: wGridControlPanel, event: wEvent) =
    # We receive a pointer-to-float and display it
    let val = derefAs[WType](event)
    when WType is SomeFloat:
      let rxstr = &"{val:g}"
    elif WType is SomeInteger:
      let rxstr = $val
    if event.mMsg == idMsgGridSizeX:
      self.mTxtSizeX.setValue(rxstr)
    elif event.mMsg == idMsgGridSizeY:
      self.mTxtSizeY.setValue(rxstr)
  proc onMsgGridDivisionsSelect(self: wGridControlPanel, event: wEvent) =
    self.mCbDivisions.select(event.lParam)
  proc onMsgGridDivisionsValue(self: wGridControlPanel, event: wEvent) =
    self.mCbDivisions.setValue($event.lParam)
  proc onMsgGridDivisionsReset(self: wGridControlPanel, event: wEvent) = 
    # Change divisions based on allowed divisions, sent after a 
    # change in sizeX or sizeY.  If allowed divisions is empty,
    # then current divisions are not changed, otherwise find
    # closest match to old index.
    discard event
    let oldidx = self.mCbDivisions.selection
    let oldval = self.mCbDivisions.value

    self.mCbDivisions.clear()
    for s in self.mGrid.allowedDivisionsStr:
      self.mCbDivisions.append(s)

    let adivs = self.mGrid.allowedDivisions
    if adivs.len > 0:
      let newidx = clamp(oldidx, 0..<adivs.len)
      let newval = adivs[newidx]
      sendToListeners(idMsgGridDivisionsSelect, self.mHwnd.WPARAM, newidx.LPARAM)
      self.mGrid.divisions = newval

  proc onMsgGridDensity(self: wGridControlPanel, event: wEvent) =
    self.mSliderDensity.setValue(event.lParam)
  #--
  proc onMsgGridSnap(self: wGridControlPanel, event: wEvent) =
    self.mCbSnap.value = event.lParam.bool
  proc onMsgGridDynamic(self: wGridControlPanel, event: wEvent) =
    self.mCbDynamic.value = event.lParam.bool
  proc onMsgGridBaseSync(self: wGridControlPanel, event: wEvent) =
    self.mCbBaseSync.value = event.lParam.bool
  #--
  proc onMsgGridVisible(self: wGridControlPanel, event: wEvent) =
    let state = event.lParam.bool
    self.mCbVisible.value = state
    self.mRbDots.enable(state)
    self.mRbLines.enable(state)
  proc onMsgGridDots(self: wGridControlPanel, event: wEvent) =
    self.mRbDots.value = event.lParam.bool
    self.mRbLines.value = not event.lParam.bool
  proc onMsgGridLines(self: wGridControlPanel, event: wEvent) =
    self.mRbLines.value = event.lParam.bool
    self.mRbDots.value = not event.lParam.bool
  proc onMsgGridZoom(self: wGridControlPanel, event: wEvent) =
    let md = self.mGrid.minDelta(Major)
    echo md
    self.mTxtSizeX.setValue($md.x)
    self.mTxtSizeY.setValue($md.y)


  proc init*(self: wGridControlPanel, parent: wWindow, gr: Grid) =
    wPanel(self).init(parent)
    self.backgroundColor = panelBackgroundColor
    # Create controls
    self.mGrid          = gr
    self.mZctrl         = gr.mZctrl
    self.mBDone         = Button(self, idDone, "Done")
    self.mIntervalBox   = StaticBox(self, label="Interval")
    self.mBehaviorBox   = StaticBox(self, label="Behavior")
    self.mAppearanceBox = StaticBox(self, label="Appearance")

    self.mTxtX          = StaticText(self, label="X")
    self.mTxtY          = StaticText(self, label="Y")
    self.mTxtDivs       = StaticText(self, label="Divisions")
    self.mTxtDens       = StaticText(self, label="Magnification")
    self.mTxtSizeX      = TextCtrl(self, idSpaceX, style=wBorderStatic)
    self.mTxtSizeY      = TextCtrl(self, idSpaceY, style=wBorderStatic)
    self.mCbDivisions   = ComboBox(self, idDivisions, choices=gr.allowedDivisionsStr)
    self.mSliderDensity = Slider(self, idDensity)
    self.mCbSnap        = CheckBox(self, idSnap, "Snap")
    self.mCbVisible     = CheckBox(self, idVisible, "Visible")
    self.mCbDynamic     = CheckBox(self, idDynamic, "Dynamic")
    self.mCbBaseSync    = CheckBox(self, idBaseSync, "Cool zoom")
    self.mRbDots        = RadioButton(self, idDots, "Dots")
    self.mRbLines       = RadioButton(self, idLines, "Lines")

    
    self.mTxtSizeX.setValue($self.mGrid.minDelta(Major).x)
    self.mTxtSizeY.setValue($self.mGrid.minDelta(Major).y)
    self.mCbDivisions.select(self.mGrid.divisionsindex)
    self.mSliderDensity.setValue((self.mZctrl.density * 100.0).int)
    self.mSliderDensity.setRange(10 .. 200) # from .1 to 2.0
    self.mCbSnap.setValue(self.mGrid.mSnap)
    self.mCbVisible.setValue(self.mGrid.mVisible)
    self.mCbDynamic.setValue(self.mGrid.mZctrl.dynamic)
    self.mCbBaseSync.setValue(self.mGrid.mZctrl.baseSync)
    self.mRbDots.setValue(self.mGrid.mDotsOrLines == Dots)
    self.mRbLines.setValue(self.mGrid.mDotsOrLines == Lines)
    
    self.layout()

    # Respond generic events
    self.wEvent_Size  do (event: wEvent): self.onResize()
    self.wEvent_Paint do (event: wEvent): self.onPaint(event)

    # Respond to controls
    self.WM_CTLCOLOREDIT do (event: wEvent): self.colorEdit(event)
    
    self.mTxtSizeX.wEvent_TextEnter    do (event: wEvent): self.onCmdTxtSizeEnter(event)
    self.mTxtSizeY.wEvent_TextEnter    do (event: wEvent): self.onCmdTxtSizeEnter(event)
    self.mCbDivisions.wEvent_ComboBox  do (event: wEvent): self.onCmdCbDivisionsSelect(event)
    self.mCbDivisions.wEvent_TextEnter do (event: wEvent): self.onCmdCbDivisionsTextEnter(event)
    self.mSliderDensity.wEvent_Slider  do (event: wEvent): self.onCmdSliderDensity(event)
    #--
    self.mCbSnap.wEvent_CheckBox      do (event: wEvent): self.onCmdSnap(event)
    self.mCbDynamic.wEvent_CheckBox   do (event: wEvent): self.onCmdDynamic(event)
    self.mCbBaseSync.wEvent_CheckBox  do (event: wEvent): self.onCmdGridBaseSync(event)
    #--
    self.mCbVisible.wEvent_CheckBox   do (event: wEvent): self.onCmdGridVisible(event)
    self.mRbDots.wEvent_RadioButton   do (event: wEvent): self.onCmdDots(event)
    self.mRblines.wEvent_RadioButton  do (event: wEvent): self.onCmdLines(event)

    # Update controls from outside messages
    self.registerListener(idMsgGridSizeX,     (w:wWindow, e:wEvent)=>(onMsgGridSize(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridSizeY,     (w:wWindow, e:wEvent)=>(onMsgGridSize(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridDivisionsSelect, (w:wWindow, e:wEvent)=>(onMsgGridDivisionsSelect(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridDivisionsValue,  (w:wWindow, e:wEvent)=>(onMsgGridDivisionsValue(w.wGridControlPanel, e)))
    #self.registerListener(idMsgGridDivisionsReset,  (w:wWindow, e:wEvent)=>(onMsgGridDivisionsReset(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridDensity,   (w:wWindow, e:wEvent)=>(onMsgGridDensity(w.wGridControlPanel, e)))
    #--
    self.registerListener(idMsgGridSnap,      (w:wWindow, e:wEvent)=>(onMsgGridSnap(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridDynamic,   (w:wWindow, e:wEvent)=>(onMsgGridDynamic(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridBaseSync,  (w:wWindow, e:wEvent)=>(onMsgGridBaseSync(w.wGridControlPanel, e)))
    #--
    self.registerListener(idMsgGridVisible,   (w:wWindow, e:wEvent)=>(onMsgGridVisible(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridDots,      (w:wWindow, e:wEvent)=>(onMsgGridDots(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridLines,     (w:wWindow, e:wEvent)=>(onMsgGridLines(w.wGridControlPanel, e)))
    #--
    self.registerListener(idMsgGridZoom, (w:wWindow, e:wEvent)=>(onMsgGridZoom(w.wGridControlPanel, e)))
    self.mBDone.wEvent_Button        do(): self.parent.destroy()
    #self.wEvent_Destroy do(): self.deregisterListener()
    self.wEvent_Close do(): self.deregisterListener()






wClass(wGridControlFrame of wFrame):
  proc onDestroy(self: wGridControlFrame) = 
    sendToListeners(idMsgGridCtrlFrameClosing, self.mHwnd.WPARAM, 0)

  proc init*(self: wGridControlFrame, owner: wWindow, gr: Grid) =
    let
      sz: wSize = (self.dpiScale(450), self.dpiScale(240))
      style = wModalFrame
    wFrame(self).init(owner, title="Grid Settings", size=sz, style=style)
    self.marginLeft  = self.dpiScale(12)
    self.marginRight = self.dpiScale(12)
    self.marginUp    = self.dpiScale(12)
    self.marginDown  = self.dpiScale(0)
    self.backgroundColor = frameBackgroundColor
    self.mPanel = GridControlPanel(self, gr)
    #self.wEvent_Destroy do(): self.onDestroy()
    self.wEvent_Close do(): self.onDestroy()


when isMainModule:
  try:
    wSetSystemDPIAware()
    let
      app = App()
      zc = newZoomCtrl(base=5, clickDiv=2400, maxPwr=5, 
                       density=1.0, dynamic=true, baseSync=true)
      gr = newGrid(zc)
      f1 = GridControlFrame(nil, gr)
    echo gr[]
    f1.show()
    app.mainLoop()
  except Exception as e:
    echo e.msg
    echo e.getStackTrace()
