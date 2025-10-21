import wNim


type
  CtrlID = enum
    idSpaceX = wIdUser, idSpaceY, idDivisions, idDensity,
    idSnap, idDynamic,
    idVisible, idDots, idLines
    

  wGridControlPanel* = ref object of wPanel
    mBox*:         wStaticBox
    mTxtInterval*: wStaticText
    mTxtX*:        wStaticText
    mTxtY*:        wStaticText
    mTxtBeh*:      wStaticText
    mTxtDivs*:     wStaticText
    mTxtDens*:     wStaticText
    mTxtApp*:      wStaticText
    mCbSnap*:      wCheckBox
    mCbVisible*:   wCheckBox
    mCbDynamic*:   wCheckBox
    mRbDots*:      wRadioButton
    mRbLines*:     wRadioButton
    mSpinSizeX*:   wSpinCtrl 
    mSpinSizeY*:   wSpinCtrl 
    mSpinDivs*:    wSpinCtrl
    mSpinDensity*: wSpinCtrl

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
      marg = 8
      hspc = 16
      vspc = 8
      spwidth = 60
    var t, b, l, r: int

    self.mBox.position = (marg, marg)
    self.mBox.size = (self.size.width - marg*2, self.size.height - marg*2)
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
    let vadj1 = 5
    let vadj2 = 4
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

  proc onResize(self: wGridControlPanel) =
    self.layout()

  proc onSnap(self: wGridControlPanel, event: wEvent) =
    echo "snap"

  proc onVisible(self: wGridControlPanel, event: wEvent) =
    echo "visible"

  proc init*(self: wGridControlPanel, parent: wWindow) =
    wPanel(self).init(parent)

    # Create controls
    let style = wDefault #wBorderSimple
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
    self.mSpinSizeX   = SpinCtrl(self, idSpaceX, "10")
    self.mSpinSizeY   = SpinCtrl(self, idSpaceY, "10")
    self.mSpinDivs    = SpinCtrl(self, idDivisions, "5")
    self.mSpinDensity = SpinCtrl(self, idDensity, "1.0")
    self.layout()

    # Connect events
    self.wEvent_Size                    do (event: wEvent): self.onResize()
    self.mCbSnap.wEvent_CheckBox        do (event: wEvent): self.onSnap(event)
    self.mCbVisible.wEvent_CheckBox     do (event: wEvent): self.onVisible(event)

when isMainModule:
  let 
    app = App()
    f = Frame(nil, "Test Frame", size=(454, 250))
    p = GridControlPanel(f)
  f.show()
  app.mainLoop()
