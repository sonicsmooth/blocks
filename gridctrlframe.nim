import wNim
from winim/inc/winbase import MulDiv
import appinit, grid, viewport

# Create a panel to hold some controls,
# then place it in a frame

type
  CtrlID = enum
    idSpaceX = wIdUser, idSpaceY, idDivisions, idDensity,
    idSnap, idDynamic,
    idVisible, idDots, idLines
  wGridControlPanel = ref object of wPanel
    mFirstLayout: bool
    mGrid:        Grid
    mZctrl:       ZoomCtrl
    mBox:         wStaticBox
    mTxtInterval: wStaticText
    mTxtX:        wStaticText
    mTxtY:        wStaticText
    mTxtBeh:      wStaticText
    mTxtDivs:     wStaticText
    mTxtDens:     wStaticText
    mTxtApp:      wStaticText
    mCbSnap:      wCheckBox
    mCbVisible:   wCheckBox
    mCbDynamic:   wCheckBox
    mRbDots:      wRadioButton
    mRbLines:     wRadioButton
    mSpinSizeX:   wSpinCtrl 
    mSpinSizeY:   wSpinCtrl 
    mSpinDivs:    wSpinCtrl
    mSpinDensity: wSpinCtrl
  wGridControlFrame* = ref object of wFrame
    mPanel: wGridControlPanel

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
      marg = self.dpiScale(8)
      hspc = self.dpiScale(16)
      vspc = self.dpiScale(8)
      spwidth = self.dpiScale(60)
    var t, b, l, r: int

    self.mBox.position = (marg, marg)
    (l,r,t,b) = edges(self.mBox)

    # First row
    self.mTxtInterval.position = (l + marg, t + vspc*2)
    (l,r,t,b) = edges(self.mTxtInterval)

    self.mTxtX.position = (l + marg, b)
    (l,r,t,b) = edges(self.mTxtX)

    self.mSpinSizeX.position = (r, t)
    self.mSpinSizeX.size = (spwidth, self.mSpinSizeX.size.height)
    (l,r,t,b) = edges(self.mSpinSizeX)

    self.mTxtY.position = (r + hspc, t)
    (l,r,t,b) = edges(self.mTxtY)

    self.mSpinSizeY.position = (r, t)
    self.mSpinSizeY.size = (spwidth, self.mSpinSizeY.size.height)
    (l,r,t,b) = edges(self.mSpinSizeY)

    self.mTxtDivs.position = (r + hspc, t)
    (l,r,t,b) = edges(self.mTxtDivs)

    self.mSpinDivs.position = (r, t)
    self.mSpinDivs.size = (spwidth, self.mSpinDivs.size.height)
    (l,r,t,b) = edges(self.mSpinDivs)

    self.mTxtDens.position = (r + hspc, t)
    (l,r,t,b) = edges(self.mTxtDens)

    self.mSpinDensity.position = (r, t)
    self.mSpinDensity.size = (spwidth, self.mSpinDensity.size.height)
    (l,r,t,b) = edges(self.mSpinDensity)

    # Second row
    l = self.mBox.position.x
    self.mTxtBeh.position = (l + marg, b + vspc*2)
    (l,r,t,b) = edges(self.mTxtBeh)

    self.mCbSnap.position = (l + marg, b)
    (l,r,t,b) = edges(self.mCbSnap)

    self.mCbDynamic.position = (r + hspc, t)
    (l,r,t,b) = edges(self.mCbDynamic)
    
    # Third row
    l = self.mBox.position.x
    self.mTxtApp.position = (l + marg, b + vspc*2)
    (l,r,t,b) = edges(self.mTxtApp)

    self.mCbVisible.position = (l + marg, b)
    (l,r,t,b) = edges(self.mCbVisible)

    self.mRbDots.position = (r + hspc, t)
    (l,r,t,b) = edges(self.mRbDots)
    
    self.mRbLines.position = (r + hspc, t)
    (l,r,t,b) = edges(self.mRbLines)

    # Minor text adjustments
    let vadj1 = self.dpiScale(5)
    let vadj2 = self.dpiScale(2)
    self.mTxtInterval.moveby(0, vadj1)
    self.mTxtBeh.moveby(0, vadj1)
    self.mTxtApp.moveby(0, vadj1)
    self.mTxtX.moveby(0, vadj2)
    self.mTxtY.moveby(0, vadj2)
    self.mTxtDivs.moveby(0, vadj2)
    self.mTxtDens.moveby(0, vadj2)

    # Finalize box size
    let (xl,xr,xt,xb) = edges(self.mTxtInterval)
    let (dl,dr,dt,tb) = edges(self.mSpinDensity)
    let (il,ir,it,ib) = edges(self.mRbLines)
    let bw = dr - xl + 2*marg
    let bh = ib - xt +  vspc*2 + marg
    self.mBox.size = (bw, bh)

    if not self.mFirstLayout:
      self.parent.size = (bw + marg*4, bh + marg*7)
      self.mFirstLayout = true

  proc onResize(self: wGridControlPanel) =
    self.layout()

  proc onSnap(self: wGridControlPanel, event: wEvent) =
    echo "snap"

  proc onVisible(self: wGridControlPanel, event: wEvent) =
    # Do something here that broadcasts the visibility value back to grid
    self.mGrid.visible = event.value.bool
    
  proc init*(self: wGridControlPanel, parent: wWindow, gr: Grid, zc: ZoomCtrl) =
    wPanel(self).init(parent)

    # Create controls
    let style = wDefault #wBorderSimple
    self.mGrid        = gr
    self.mZctrl       = zc
    self.mBox         = StaticBox(self, 0, "Grid Controls")
    self.mTxtInterval = StaticText(self, 0, "Interval")
    self.mTxtX        = StaticText(self, 0, "X")
    self.mTxtY        = StaticText(self, 0, "Y")
    self.mTxtBeh      = StaticText(self, 0, "Behavior")
    self.mTxtDivs     = StaticText(self, 0, "Divisions")
    self.mTxtDens     = StaticText(self, 0, "Density")
    self.mTxtApp      = StaticText(self, 0, "Appearance:")
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
    self.layout()

    # Connect events
    self.wEvent_Size                    do (event: wEvent): self.onResize()
    self.mCbSnap.wEvent_CheckBox        do (event: wEvent): self.onSnap(event)
    self.mCbVisible.wEvent_CheckBox     do (event: wEvent): self.onVisible(event)

wClass(wGridControlFrame of wFrame):
  proc init*(self: wGridControlFrame, owner: wWindow, gr: Grid, zc: ZoomCtrl) =
    let
      w = self.dpiScale(450)
      h = self.dpiScale(240)
      sz: wSize = (w, h)
    wFrame(self).init(owner, title="Grid Settings", size=sz, style=wDefaultFrameStyle)
    self.mPanel = GridControlPanel(self, gr, zc)

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
