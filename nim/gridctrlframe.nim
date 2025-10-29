import std/[math, strformat, sugar, strutils, parseutils]
import wNim
from winim/inc/winbase import MulDiv
import winim
import appinit, grid, viewport
import routing

# Create a panel to hold some controls,
# then place it in a frame

type
  CtrlID = enum
    idSpaceX = wIdUser, idSpaceY, idDivisions, idDensity,
    idSnap, idDynamic,
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
    mRbDots:        wRadioButton
    mRbLines:       wRadioButton
    mSpinSizeX:     wSpinCtrl 
    mSpinSizeY:     wSpinCtrl 
    mSpinDivisions: wSpinCtrl
    mSpinDensity:   wSpinCtrl
  wGridControlFrame* = ref object of wFrame
    mPanel: wGridControlPanel

const
  frameBackgroundColor = 0xebebeb
  panelBackgroundColor = 0xf0f0f0
  buttonAreaColor = 0xf5f5f5

proc edges(w: wWindow): tuple[left, right, top, bot: int] =
  (left:  w.position.x,
    right: w.position.x + w.size.width,
    top:   w.position.y,
    bot:   w.position.y + w.size.height)

proc moveby(w: wWindow, dx, dy: int) =
  w.position = (w.position.x + dx, w.position.y + dy)

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

    self.mSpinSizeX.position = (r, vmarg)
    self.mSpinSizeX.size = (spwidth, self.mSpinSizeX.size.height)
    (l,r,t,b) = edges(self.mSpinSizeX)

    self.mTxtY.position = (r + hspc, vmarg)
    (l,r,t,b) = edges(self.mTxtY)

    self.mSpinSizeY.position = (r, vmarg)
    self.mSpinSizeY.size = (spwidth, self.mSpinSizeY.size.height)
    (l,r,t,b) = edges(self.mSpinSizeY)

    self.mTxtDivs.position = (r + hspc, vmarg)
    (l,r,t,b) = edges(self.mTxtDivs)

    self.mSpinDivisions.position = (r, vmarg)
    self.mSpinDivisions.size = (spwidth, self.mSpinDivisions.size.height)
    (l,r,t,b) = edges(self.mSpinDivisions)

    self.mTxtDens.position = (r + hspc, vmarg)
    (l,r,t,b) = edges(self.mTxtDens)

    self.mSpinDensity.position = (r, vmarg)
    self.mSpinDensity.size = (spwidth, self.mSpinDensity.size.height)

    self.mIntervalBox.contain(self.mTxtX, self.mSpinSizeX, self.mTxtY, self.mSpinSizeY,
                              self.mTxtDivs, self.mSpinDivisions, self.mTxtDens, self.mSpinDensity)
    (l,r,t,b) = edges(self.mIntervalBox)

    # Second box (second row)
    let secondrowtop = b + vspc
    self.mCbSnap.position = (hmarg, secondrowtop)
    (_,r,t,_) = edges(self.mCbSnap)

    self.mCbDynamic.position = (r + hspc, secondrowtop)
    self.mBehaviorBox.contain(self.mCbSnap, self.mCbDynamic)

    (l,r,t,b) = edges(self.mBehaviorBox)
    
    # Third box (second row)
    self.mCbVisible.position = (r + hspc*3+8, secondrowtop)
    (l,r,t,b) = edges(self.mCbVisible)

    self.mRbDots.position = (r + hspc, secondrowtop)
    (l,r,t,b) = edges(self.mRbDots)
    
    self.mRbLines.position = (r + hspc, secondrowtop)
    (l,r,t,b) = edges(self.mRbLines)

    self.mAppearanceBox.contain(self.mCbVisible, self.mRbDots, self.mRbLines)
    
    (l,r,t,b) = edges(self.mAppearanceBox)
    let rightmost = r

    # Done button
    self.mBDone.position = (rightmost - buttWidth, b + vspc div 2 + self.dpiScale(6))
    self.mBDone.size = (buttWidth, buttHeight)
    (l,r,t,b) = edges(self.mBDone)

    # Minor text adjustments
    let vadj1 = self.dpiScale(5)
    let vadj2 = self.dpiScale(2)
    self.mTxtX.moveby(0, vadj2)
    self.mTxtY.moveby(0, vadj2)
    self.mTxtDivs.moveby(0, vadj2)
    self.mTxtDens.moveby(0, vadj2)

    # Finalize frame size, then gray rectangle
    let (ibxl,ibxr,ibxt,ibxb) = edges(self.mIntervalBox)
    let (abxl,ablr,abxt,abxb) = edges(self.mBDone)
    let frameW = self.mIntervalBox.size.width + 2*hmarg + self.dpiScale(6)
    let frameH = abxb - ibxt + self.parent.margin.up + self.parent.margin.down + self.dpiScale(50) 
    self.parent.size = (frameW, frameH)
  proc onResize(self: wGridControlPanel) =
    self.layout()
  proc onPaint(self: wGridControlPanel, event: wEvent) = 
    var dc = PaintDC(self)
    let
      sz = self.size
      buttHeight = self.dpiScale(30)
      barheight = buttHeight +  self.dpiScale(20)

    # Rectangle behind button
    dc.setBrush(Brush(buttonAreaColor.wColor))
    dc.setPen(Pen(buttonAreaColor.wColor))
    dc.drawRectangle(0, sz.height - barheight, sz.width, barheight)

  # Respond to controls
  proc onCmdSpinSizeX(self: wGridControlPanel, event: wEvent) =
    when defined(debug):
      echo "Spin size X = ", self.mSpinSizeX.value

  proc onCmdSpinSizeY(self: wGridControlPanel, event: wEvent) =
    when defined(debug):
      echo "Spin size Y = ", self.mSpinSizeY.value

  proc onCmdSpinDivisions(self: wGridControlPanel, event: wEvent) =
    let
      val = self.mSpinDivisions.value
      delta = event.spinDelta
      finalval = clamp(val + delta, self.mSpinDivisions.range)
    when defined(debug):
      echo &"Division spinner sending val={finalval}"
    sendToListeners(idMsgGridDivisions, self.mHwnd.WPARAM, finalval.LPARAM)

  proc onCmdSpinTxtDivisions(self: wGridControlPanel, event: wEvent) =
    var valf: float
    let nchars = parseBiggestFloat(self.mSpinDivisions.text, valf)
    when defined(debug):
      if nchars == 0:
        echo &"could not parse \"{self.mSpinDivisions.text}\""
    let finalval = clamp(valf.round.int, self.mSpinDivisions.range)
    when defined(debug):
      echo &"Division spinner sending val={finalval}"
    sendToListeners(idMsgGridDivisions, self.mHwnd.WPARAM, finalval.LPARAM)

  proc onCmdSpinDensity(self: wGridControlPanel, event: wEvent) =
    when defined(debug):
      echo "spin density = ", self.mSpinDensity.value + event.spinDelta

  proc onCmdSnap(self: wGridControlPanel, event: wEvent) =
    let state = self.mCbSnap.value
    sendToListeners(idMsgGridSnap, self.mHwnd, state.LPARAM)

  proc onCmdDynamic(self: wGridControlPanel, event: wEvent) =
    let state = self.mCbDynamic.value
    sendToListeners(idMsgGridDynamic, self.mHwnd, state.LPARAM)

  proc onCmdGridVisible(self: wGridControlPanel, event: wEvent) =
    # Read state from button and broadcast to everyone
    let state = self.mCbVisible.value
    sendToListeners(idMsgGridVisible, self.mHwnd, state.LPARAM)

  proc onCmdDots(self: wGridControlPanel, event: wEvent) =
    let state = self.mRbDots.value
    sendToListeners(idMsgGridDots, self.mHwnd, state.LPARAM)

  proc onCmdLines(self: wGridControlPanel, event: wEvent) =
    let state = self.mRbLines.value
    sendToListeners(idMsgGridLines, self.mHwnd, state.LPARAM)

  # Respond to incoming messages
  proc onMsgGridDivisions(self: wGridControlPanel, event: wEvent) =
    when defined(debug):
      echo &"onMsgGridDivisions receiving {event.lParam}"
    let val = event.lParam
    self.mSpinDivisions.value = $val
    self.mZctrl.base = val

  proc onMsgGridSnap(self: wGridControlPanel, event: wEvent) =
    when defined(debug):
      echo "onMsgGridSnap"
    let state = event.lParam.bool
    self.mCbSnap.setValue(state)
    self.mGrid.mSnap = state

  proc onMsgGridDynamic(self: wGridControlPanel, event: wEvent) =
    when defined(debug):
      echo "onMsgGridDynamic"
    let state = event.lParam.bool
    self.mCbDynamic.setValue(state)

  proc onMsgGridVisible(self: wGridControlPanel, event: wEvent) =
    when defined(debug):
      echo "onMsgGridVisible"
    # Accept the message and update state
    # This responds to self-messages
    let state = event.lParam.bool
    self.mCbVisible.setValue(state)
    self.mRbDots.enable(state)
    self.mRbLines.enable(state)
    self.mGrid.mVisible = state

  proc onMsgGridDots(self: wGridControlPanel, event: wEvent) =
    # We only get this when state is true
    when defined(debug):
      echo "onMsgGridDots"
      echo event.lParam

  proc onMsgGridLines(self: wGridControlPanel, event: wEvent) =
    # We only get this when state is true
    when defined(debug):
      echo "onMsgGridLines"
      echo event.lParam



  proc init*(self: wGridControlPanel, parent: wWindow, gr: Grid) =
    wPanel(self).init(parent)
    when defined(debug):
      echo "Grid control panel is ", self.mHwnd
    self.backgroundColor = panelBackgroundColor
    # Create controls
    self.mGrid          = gr
    self.mZctrl         = gr.mZctrl
    self.mBDone         = Button(self, idDone, "Done")
    self.mIntervalBox   = StaticBox(self, 0, "Interval")
    self.mBehaviorBox   = StaticBox(self, 0, "Behavior")
    self.mAppearanceBox = StaticBox(self, 0, "Appearance")

    self.mTxtX          = StaticText(self, 0, "X")
    self.mTxtY          = StaticText(self, 0, "Y")
    self.mTxtDivs       = StaticText(self, 0, "Divisions")
    self.mTxtDens       = StaticText(self, 0, "Density")
    self.mSpinSizeX     = SpinCtrl(self, idSpaceX, "", style=wSpArrowKeys)
    self.mSpinSizeY     = SpinCtrl(self, idSpaceY, "", style=wSpArrowKeys)
    self.mSpinDivisions = SpinCtrl(self, idDivisions, "", style=wSpArrowKeys)
    self.mSpinDensity   = SpinCtrl(self, idDensity, "", style=wSpArrowKeys)
    self.mCbSnap        = CheckBox(self, idSnap, "Snap")
    self.mCbVisible     = CheckBox(self, idVisible, "Visible")
    self.mCbDynamic     = CheckBox(self, idDynamic, "Dynamic Grid")
    self.mRbDots        = RadioButton(self, idDots, "Dots")
    self.mRbLines       = RadioButton(self, idLines, "Lines")

    self.mSpinSizeX.setValue($self.mGrid.majorXSpace)
    self.mSpinSizeX.setRange(1 .. 1000)
    self.mSpinSizeY.setValue($self.mGrid.majorYSpace)
    self.mSpinSizeY.setRange(1 .. 1000)
    self.mSpinDivisions.setValue($self.mZctrl.base)
    self.mSpinDivisions.setRange(2 .. 10)
    self.mSpinDensity.setValue($self.mZctrl.density)
    self.mCbSnap.setValue(self.mGrid.mSnap)
    self.mCbVisible.setValue(self.mGrid.mVisible)
    self.mCbDynamic.setValue(self.mGrid.mDynamic)
    self.mRbDots.setValue(self.mGrid.mDotsOrLines == Dots)
    self.mRbLines.setValue(self.mGrid.mDotsOrLines == Lines)
    
    self.layout()

    # Respond generic events
    self.wEvent_Size  do (event: wEvent): self.onResize()
    self.wEvent_Paint do (event: wEvent): self.onPaint(event)

    # Respond to controls
    self.mSpinSizeX.wEvent_Spin     do (event: wEvent): self.onCmdSpinSizeX(event)
    self.mSpinSizeX.wEvent_TextEnter do (event: wEvent): self.onCmdSpinSizeX(event)
    self.mSpinSizeY.wEvent_Spin     do (event: wEvent): self.onCmdSpinSizeY(event)
    self.mSpinSizeY.wEvent_TextEnter do (event: wEvent): self.onCmdSpinSizeY(event)
    self.mSpinDivisions.wEvent_SpinUp do (event: wEvent): self.onCmdSpinDivisions(event)
    self.mSpinDivisions.wEvent_SpinDown do (event: wEvent): self.onCmdSpinDivisions(event)
    self.mSpinDivisions.wEvent_TextEnter do (event: wEvent): self.onCmdSpinTxtDivisions(event)
    self.mSpinDensity.wEvent_Spin   do (event: wEvent): self.onCmdSpinDensity(event)

    self.mCbSnap.wEvent_CheckBox     do (event: wEvent): self.onCmdSnap(event)
    self.mCbDynamic.wEvent_CheckBox  do (event: wEvent): self.onCmdDynamic(event)
    self.mCbVisible.wEvent_CheckBox  do (event: wEvent): self.onCmdGridVisible(event)
    self.mRbDots.wEvent_RadioButton  do (event: wEvent): self.onCmdDots(event)
    self.mRblines.wEvent_RadioButton do (event: wEvent): self.onCmdLines(event)

    # Update controls from outside messages
    self.registerListener(idMsgGridDivisions, (w:wWindow,e:wEvent)=>(onMsgGridDivisions(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridSnap,    (w:wWindow,e:wEvent)=>(onMsgGridSnap(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridDynamic, (w:wWindow,e:wEvent)=>(onMsgGridDynamic(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridVisible, (w:wWindow,e:wEvent)=>(onMsgGridVisible(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridDots,    (w:wWindow,e:wEvent)=>(onMsgGridDots(w.wGridControlPanel, e)))
    self.registerListener(idMsgGridLines,   (w:wWindow,e:wEvent)=>(onMsgGridLines(w.wGridControlPanel, e)))


    self.mBDone.wEvent_Button        do(): self.parent.destroy()
    self.wEvent_Destroy do(): self.deregisterListener()


wClass(wGridControlFrame of wFrame):
  proc onDestroy(self: wGridControlFrame) = 
    sendToListeners(idMsgSubFrameClosing, self.mHwnd.WPARAM, 0)

  proc init*(self: wGridControlFrame, owner: wWindow, gr: Grid) =
    let
      w = self.dpiScale(450)
      h = self.dpiScale(240)
      sz: wSize = (w, h)
    let style = wModalFrame
    wFrame(self).init(owner, title="Grid Settings", size=sz, style=style)
    when defined(debug):
      echo "Grid control frame is ", self.mHwnd
    self.margin = self.dpiScale(6)
    self.backgroundColor = frameBackgroundColor
    self.mPanel = GridControlPanel(self, gr)
    self.wEvent_Destroy do(): self.onDestroy()


when isMainModule:
  try:
    wSetSystemDPIAware()
    let
      app = App()
      zc = newZoomCtrl(base=5, clickDiv=2400, maxPwr=5, density=1.0)
      gr = newGrid(zc)
      f1 = GridControlFrame(nil, gr)
    f1.show()
    app.mainLoop()
  except Exception as e:
    echo e.msg
    echo e.getStackTrace()
