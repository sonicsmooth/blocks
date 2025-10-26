import std/strformat
import wNim
from winim/inc/winbase import MulDiv
import winim
import appinit, grid, viewport
import userMessages

# Create a panel to hold some controls,
# then place it in a frame

type
  CtrlID = enum
    idSpaceX = wIdUser, idSpaceY, idDivisions, idDensity,
    idSnap, idDynamic,
    idVisible, idDots, idLines, idDone
  wGridControlPanel = ref object of wPanel
    mGrid:        Grid
    mZctrl:       ZoomCtrl
    mBDone:       wButton
    mIntervalBox: wStaticbox
    mBehaviorBox: wStaticBox
    mAppearanceBox: wStaticBox
    mTxtX:        wStaticText
    mTxtY:        wStaticText
    mTxtDivs:     wStaticText
    mTxtDens:     wStaticText
    mCbSnap:      wCheckBox
    mCbVisible:   wCheckBox
    mCbDynamic:   wCheckBox
    mRbDots:      wRadioButton
    mRbLines:     wRadioButton
    mSpinSizeX:   wSpinCtrl 
    mSpinSizeY:   wSpinCtrl 
    mSpinDivs:    wSpinCtrl
    mSpinDensity: wSpinCtrl
    mFirstLayout: bool
  wGridControlFrame* = ref object of wFrame
    mPanel: wGridControlPanel
    mOwner: wWindow # app main window to where messages will be sent

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

    self.mSpinDivs.position = (r, vmarg)
    self.mSpinDivs.size = (spwidth, self.mSpinDivs.size.height)
    (l,r,t,b) = edges(self.mSpinDivs)

    self.mTxtDens.position = (r + hspc, vmarg)
    (l,r,t,b) = edges(self.mTxtDens)

    self.mSpinDensity.position = (r, vmarg)
    self.mSpinDensity.size = (spwidth, self.mSpinDensity.size.height)

    self.mIntervalBox.contain(self.mTxtX, self.mSpinSizeX, self.mTxtY, self.mSpinSizeY,
                              self.mTxtDivs, self.mSpinDivs, self.mTxtDens, self.mSpinDensity)
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
    self.mBDone.position = (rightmost - buttWidth, b + vspc div 2 + self.dpiScale(12))
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
    let frameW = self.mIntervalBox.size.width + 2*hmarg + self.dpiScale(12)
    let frameH = abxb - ibxt + self.dpiScale(60) + self.parent.margin.up + self.parent.margin.down
    if not self.mFirstLayout:
      self.parent.size = (frameW, frameH)
      self.mFirstLayout = true
  proc onResize(self: wGridControlPanel) =
    self.layout()
  proc onPaint(self: wGridControlPanel, event: wEvent) = 
    var dc = PaintDC(self)
    let
      sz = self.size
      buttHeight = self.dpiScale(30)
      barheight = buttHeight +  self.dpiScale(20)

    # Rectangle behind button
    dc.setBrush(Brush(0xf0f0f0.wColor))
    dc.setPen(Pen(0xf0f0f0.wColor))
    dc.drawRectangle(0, sz.height - barheight, sz.width, barheight)

  proc sendMessageToRoot(self: wGridControlPanel, msg: UserMsgID, wp, lp: int) =
      let owner = wGridControlFrame(self.parent).mOwner
      if owner.isNil: return
      echo &"Sending {msg} to {owner.mHwnd}"
      SendMessage(owner.mHwnd, msg.UINT, wp.WPARAM, lp.LPARAM)
   

  proc spinSize(self: wGridControlPanel, event: wEvent) =
    echo self.mSpinSizeX.value, ", ", self.mSpinSizeY.value
  proc spinDivDense(self: wGridControlPanel, event: wEvent) =
    let d = event.spinDelta
    echo self.mSpinDivs.value + d, ", ", self.mSpinDensity.value + d
  proc onSnap(self: wGridControlPanel, event: wEvent) =
    echo "snap: ", self.mCbSnap.value
  proc onDynamic(self: wGridControlPanel, event: wEvent) =
    echo "dynamic: ", self.mCbDynamic.value
  proc onVisible(self: wGridControlPanel, event: wEvent) =
    # Do something here that broadcasts the visibility value back to grid
    let val = self.mCbVisible.value
    self.mGrid.visible = val
    self.mRbDots.enable(val)
    self.mRbLines.enable(val)
    self.sendMessageToRoot(idMsgGridShow, 0, val.LPARAM)
  proc dotsOrLines(self: wGridControlPanel, event: wEvent) =
    echo self.mRbDots.value, ", ", self.mRbLines.value



  proc init*(self: wGridControlPanel, parent: wWindow, gr: Grid, zc: ZoomCtrl) =
    wPanel(self).init(parent)
    # Create controls
    self.mGrid        = gr
    self.mZctrl       = zc
    self.mBDone        = Button(self, idDone, "Done")
    self.mIntervalBox = StaticBox(self, 0, "Interval")
    self.mBehaviorBox = StaticBox(self, 0, "Behavior")
    self.mAppearanceBox = StaticBox(self, 0, "Appearance")

    self.mTxtX        = StaticText(self, 0, "X")
    self.mTxtY        = StaticText(self, 0, "Y")
    self.mTxtDivs     = StaticText(self, 0, "Divisions")
    self.mTxtDens     = StaticText(self, 0, "Density")
    self.mCbSnap      = CheckBox(self, idSnap, "Snap")
    self.mCbVisible   = CheckBox(self, idVisible, "Visible")
    self.mCbDynamic   = CheckBox(self, idDynamic, "Dynamic Grid")
    self.mRbDots      = RadioButton(self, idDots, "Dots")
    self.mRbLines     = RadioButton(self, idLines, "Lines")
    self.mSpinSizeX   = SpinCtrl(self, idSpaceX, "")
    self.mSpinSizeY   = SpinCtrl(self, idSpaceY, "")
    self.mSpinDivs    = SpinCtrl(self, idDivisions, "")
    self.mSpinDensity = SpinCtrl(self, idDensity, "")
    
    self.mSpinSizeX.setValue($self.mGrid.xSpace)
    self.mSpinSizeY.setValue($self.mGrid.ySpace)
    self.mCbVisible.setValue(self.mGrid.visible)
    self.mCbSnap.setValue(self.mGrid.snap)
    self.mCbDynamic.setValue(self.mGrid.dynamic)
    self.mRbDots.setValue(self.mGrid.dotsOrLines == Dots)
    self.mRbLines.setValue(self.mGrid.dotsOrLines == Lines)
    self.mSpinDivs.setValue($self.mZctrl.base)
    self.mSpinDensity.setValue($self.mZctrl.density)
    
    self.backgroundColor = 0xf0f0f0
    self.layout()

    # Connect events
    self.wEvent_Size                 do (event: wEvent): self.onResize()
    self.wEvent_Paint                do (event: wEvent): self.onPaint(event)
    self.mSpinSizeX.wEvent_Spin      do (event: wEvent): self.spinSize(event)
    self.mSpinSizeY.wEvent_Spin      do (event: wEvent): self.spinSize(event)
    self.mSpinDivs.wEvent_Spin       do (event: wEvent): self.spinDivDense(event)
    self.mSpinDensity.wEvent_Spin    do (event: wEvent): self.spinDivDense(event)
    self.mCbSnap.wEvent_CheckBox     do (event: wEvent): self.onSnap(event)
    self.mCbDynamic.wEvent_CheckBox  do (event: wEvent): self.onDynamic(event)
    self.mCbVisible.wEvent_CheckBox  do (event: wEvent): self.onVisible(event)
    self.mRbDots.wEvent_RadioButton  do (event: wEvent): self.dotsOrLines(event)
    self.mRblines.wEvent_RadioButton do (event: wEvent): self.dotsOrLines(event)
    self.mBDone.wEvent_Button        do(): self.parent.destroy()

wClass(wGridControlFrame of wFrame):
  proc onDestroy(self: wGridControlFrame) = 
    #echo &"closing from 0x{self.mHwnd:08x}"
    if self.mOwner.isnil: return
    SendMessage(self.mOwner.mHwnd, idMsgSubFrameClosing.UINT, self.mHwnd.WPARAM, 0)

  proc init*(self: wGridControlFrame, owner: wWindow, gr: Grid, zc: ZoomCtrl) =
    let
      w = self.dpiScale(450)
      h = self.dpiScale(240)
      sz: wSize = (w, h)
    wFrame(self).init(owner, title="Grid Settings", size=sz,)# style=wDefaultDialogStyle)
    self.mOwner = owner
    self.margin = self.dpiScale(6)
    self.backgroundColor = 0xd0d0d0
    self.mPanel = GridControlPanel(self, gr, zc)
    self.wEvent_Destroy do(): self.onDestroy()

when isMainModule:
  try:
    wSetSystemDPIAware()
    let
      app = App()
      zc = newZoomCtrl(base=5, clickDiv=2400, maxPwr=5, density=1.0)
      gr = newGrid()
      f1 = GridControlFrame(nil, gr, zc)
    f1.show()
    app.mainLoop()
  except Exception as e:
    echo e.msg
    echo e.getStackTrace()
