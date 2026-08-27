import std/[strutils,
            tables,
            parseutils]
from os import `/`
import wNim
import winim
import pixie/fileformats/[png, svg]

import routing
import viewport

# Create a panel to hold some controls,
# then place it in a frame
type
  CtrlID = enum
    idQty = wIdUser, idX, idY, idW, idH,
    idTemp, idRndAll, idRndPos, idTest
  wPlacementPanel = ref object of wPanel
    # Static Boxes
    sbBoundReg, sbCompactMethod, sbAnneal,
      sbMinSpacing, sbOrder: wStaticBox

    # Static Texts
    stQty, stSelected, stSelectedNum,
      stCompTitle, stX, stY, stW, stH,
      stMinX, stMinY, stStrat, stReplFn,
      stStartTemp, stStartTempNum,
      stCurrTemp, stCurrTempNum: wStaticText
    
    # Text Controls
    tcQty, tcX, tcY, tcW, tcH,
      tcMinX, tcMinY: wTextCtrl

    # Buttons
    bRandomizeAll, bRandomizePos, bTest, bBoundReg,
      bLeft, bRight, bUp, bDown,
      bUpLeft, bUpRight, bDnLeft, bDnRight,
      bUndo, bDone: wButton

    # Radio buttons
    rbNone, rbStack, rbAnneal, rbStrat1, rbStrat2, 
      rbWiggle, rbSwap, rbHV, rbVH: wRadioButton

    # Other
    slTemp: wSlider
    cbMonitor: wCheckBox


  wPlacementFrame* = ref object of wFrame
    mPanel: wPlacementPanel

const
  frameBackgroundColor = 0xd0d0d0
  panelBackgroundColor = 0xf0f0f0
  doneAreaColor = 0xe4e4e4 #0xf0f0f0
  buttHeightRaw = 30
  buttWidthRaw = 110
  iconSizeRaw = 40
  hmargRaw = 12
  vmargRaw = 12
  hpadRaw = 12
  vpadRaw = 12
  hspcRaw = 18
  vspcRaw = 14
  vgapRaw = 4
  suffix = ".svg"
  pth = "../../icons/claude/icons/svg"
  res = [(name: "up",      data: staticRead(pth / "arrow_up"         & suffix )),
         (name: "down",    data: staticRead(pth / "arrow_down"       & suffix )),
         (name: "left",    data: staticRead(pth / "arrow_left"       & suffix )),
         (name: "right",   data: staticRead(pth / "arrow_right"      & suffix )),
         (name: "upleft",  data: staticRead(pth / "arrow_up_left"    & suffix )),
         (name: "upright", data: staticRead(pth / "arrow_up_right"   & suffix )),
         (name: "dnleft",  data: staticRead(pth / "arrow_down_left"  & suffix )),
         (name: "dnright", data: staticRead(pth / "arrow_down_right" & suffix ))]
  #iconSize = 64
var
  #icons: Table[string, wTypes.wIcon]
  icons: Table[string, string]

for (name, data) in res:
  #icons[name] = Icon(data, (iconSize, iconSize))
  icons[name] = data

proc svgToBitmap(svgData: string, sz: wSize): wBitmap =
  let svgobj = svgData.parseSvg(sz.width, sz.height)
  let im = newImage(svgobj)
  let pngBytes = im.encodePng()
  let wimg = Image(pngBytes[0].addr, pngBytes.len)
  result = Bitmap(wimg)

proc appDpiScale(value: wSize): wSize =
  let d = wAppGetDpi()
  (value.width * d div 96, value.height * d div 96)

proc appDpiScale(value: int): int =
  value * wAppGetDpi() div 96

proc parseNumber[T:SomeNumber](s: string, number: var T): bool =
  # Returns true if s can be parsed to int or float
  # Parsed value is returned in val
  when T is SomeFloat: parseFloat(s, number) > 0
  elif T is SomeInteger: parseInt(s, number) > 0

proc errcol(event: wEvent) =
  SetBkColor(event.wParam, RGB(255, 199, 206))
  SetTextColor(event.wParam, RGB(156, 0, 6))

# template layoutAndDump(parent: wResizable, x: untyped) =
#   echo parent.layoutDebug(x)
#   parent.layout(x)

wClass(wPlacementPanel of wPanel):
  proc layout(self: wPlacementPanel) =
    let
      hmarg = self.dpiScale(hmargRaw) # from panel edge
      vmarg = self.dpiScale(vmargRaw) # from panel edge
      hpad = self.dpiScale(hpadRaw) # small spaces
      vpad = self.dpiScale(vpadRaw) # small spaces
      hspc = self.dpiScale(hspcRaw) # larger spaces
      vspc = self.dpiScale(vspcRaw) # larger spaces
      boxvspc = self.dpiScale(20) # down from top of static box to avoid text
      vgap = self.dpiScale(vgapRaw) # tiny space
      bbTxtAdjust = self.dpiScale(8) # get top compass buttons to align with box line not text
      buttWidth = self.dpiScale(buttWidthRaw)
      buttHeight = self.dpiScale(buttHeightRaw)
      arrowBtnSize = self.dpiScale(iconSizeRaw)
      txtCtrlWidth = self.dpiScale(40)

    self.stCompTitle.fit()
    self.layout:
      # Top Row
      self.stQty:
        left = self.left + hmarg
        centerY = self.bRandomizeAll.centerY
        width = self.stQty.defaultWidth
        height = self.stQty.defaultHeight
      self.tcQty:
        left = self.stQty.right
        centerY = self.bRandomizeAll.centerY
        width = txtCtrlWidth
        height = self.tcQty.defaultHeight
      self.stSelected:
        left = self.tcQty.right + hspc
        centerY = self.bRandomizeAll.centerY
        width = self.stSelected.defaultWidth
        height = self.stSelected.defaultHeight
      self.stSelectedNum:
        left = self.stSelected.right + hpad
        bottom = self.stSelected.bottom
        width = txtCtrlWidth
        height = self.stSelectedNum.defaultHeight
      self.bRandomizeAll:
        right = self.bRandomizePos.left - hspc
        top = self.top + vmarg
        width = buttWidth
        height = buttHeight
      self.bRandomizePos:
        right = self.bTest.left - hspc
        top = self.bRandomizeAll.top
        width = buttWidth
        height = buttHeight
      self.bTest:
        right == self.sbAnneal.right
        top = self.bRandomizeAll.top
        height = buttHeight
        width = self.dpiScale(80)

      # Title
      self.stCompTitle:
        left = self.left + hmarg
        top = self.bRandomizeAll.bottom + vspc
        width = self.stCompTitle.defaultWidth
        height = self.stCompTitle.defaultHeight

      # 8 Compass buttons
      self.bUpLeft:
        top = self.stCompTitle.bottom + bbTxtAdjust
        left = self.left + hmarg
        width = arrowBtnSize
        height = arrowBtnSize
      self.bUp:
        top = self.stCompTitle.bottom + bbTxtAdjust
        left = self.bUpLeft.right
        width = arrowBtnSize
        height = arrowBtnSize
      self.bUpRight:
        top = self.stCompTitle.bottom + bbTxtAdjust
        left = self.bUp.right
        width = arrowBtnSize
        height = arrowBtnSize
      self.bLeft:
        top = self.bUpLeft.bottom
        left = self.bUpLeft.left
        width = arrowBtnSize
        height = arrowBtnSize
      self.bRight:
        top = self.bUpRight.bottom
        left = self.bUpRight.left
        width = arrowBtnSize
        height = arrowBtnSize
      self.bDnLeft:
        top = self.bLeft.bottom
        left = self.bLeft.left
        width = arrowBtnSize
        height = arrowBtnSize
      self.bDown:
        top = self.bLeft.bottom
        left = self.bDnLeft.right
        width = arrowBtnSize
        height = arrowBtnSize
      self.bDnRight:
        top = self.bRight.bottom
        left = self.bDown.right
        width = arrowBtnSize
        height = arrowBtnSize

      # Static Boxes, Left
      self.sbBoundReg:
        top = self.stCompTitle.bottom
        left = self.bUpRight.right + hspc
        bottom = self.bDown.bottom
        right >= self.tcH.right + hpad
      self.sbMinSpacing:
        left = self.bLeft.left
        top = self.bDown.bottom + vspc
        bottom = self.sbAnneal.bottom
        width = self.sbOrder.width
      self.sbOrder:
        left = self.sbMinSpacing.right + hspc
        top = self.sbMinSpacing.top
        bottom = self.sbAnneal.bottom
        right = self.sbBoundReg.right

      # Static Boxes, Right
      self.sbCompactMethod:
        top = self.sbBoundReg.top
        left = self.sbBoundReg.right + hspc
        bottom = self.rbNone.bottom + vpad
        right = self.sbAnneal.right
      self.sbAnneal:
        top = self.sbCompactMethod.bottom + vspc
        left = self.sbBoundReg.right + hspc
        bottom = self.cbMonitor.bottom + vpad
        right = self.stStartTempNum.right + vmarg

      # Bounding Region contents
      self.bBoundReg:
        top = self.sbBoundReg.top + boxvspc
        left = self.sbBoundReg.left + hpad
        width = buttWidth
        height = buttHeight

      self.stX:
        top = self.bBoundReg.bottom + vpad
        left = self.sbBoundReg.left + hpad
        width = self.stX.defaultWidth
        height = self.stX.defaultHeight
      self.stY:
        top = self.bBoundReg.bottom + vpad
        left = self.tcX.right + hpad
        width = self.stY.defaultWidth
        height = self.stY.defaultHeight
      self.stW:
        top = self.bBoundReg.bottom + vpad
        left = self.tcY.right + hpad
        width = self.stW.defaultWidth
        height = self.stW.defaultHeight
      self.stH:
        top = self.bBoundReg.bottom + vpad
        left = self.tcW.right + hpad
        width = self.stH.defaultWidth
        height = self.stH.defaultHeight

      self.tcY:
        top = self.stY.bottom
        left = self.stY.left
        width = txtCtrlWidth
        height = self.tcY.defaultHeight
      self.tcX:
        top = self.stX.bottom
        left = self.stX.left
        width = txtCtrlWidth
        height = self.tcX.defaultHeight
      self.tcW:
        top = self.stW.bottom
        left = self.stW.left
        width = txtCtrlWidth
        height = self.tcW.defaultHeight
      self.tcH:
        top = self.stH.bottom
        left = self.stH.left
        width = txtCtrlWidth
        height = self.tcW.defaultHeight

      # Minimum Spacing contents
      self.tcMinX:
        top = self.sbMinSpacing.top + boxvspc
        left = self.stMinX.right
        width = txtCtrlWidth
        height = self.tcMinX.defaultHeight
      self.tcMinY:
        top = self.tcMinX.bottom + vgap
        left = self.tcMinX.left
        width = txtCtrlWidth
        height = self.tcMinY.defaultHeight
      self.stMinX:
        bottom = self.tcMinX.bottom
        left = self.sbMinSpacing.left + hpad
        width = self.stMinX.defaultWidth
        height = self.stMinX.defaultHeight
      self.stMiny:
        bottom = self.tcMinY.bottom + vgap
        left = self.sbMinSpacing.left + hpad
        width = self.stMinY.defaultWidth
        height = self.stMinY.defaultHeight

      # Order contents
      self.rbHV:
        top = self.sborder.top + boxvspc
        left = self.sbOrder.left + hpad
        width = self.rbHV.defaultWidth
        height = self.rbHV.defaultHeight
      self.rbVH:
        top = self.rbHV.bottom
        left = self.sbOrder.left + hpad
        width = self.rbVH.defaultWidth
        height = self.rbVH.defaultHeight

      # Compact Method contents
      self.rbNone:
        top = self.sbCompactMethod.top + boxvspc
        left = self.sbCompactMethod.left + hpad
        width = self.rbNone.defaultWidth
        height = self.rbNone.defaultHeight
      self.rbStack:
        top = self.sbCompactMethod.top + boxvspc
        left = self.rbNone.right + hpad
        width = self.rbStack.defaultWidth
        height = self.rbStack.defaultHeight
      self.rbAnneal:
        top = self.sbCompactMethod.top + boxvspc
        left = self.rbStack.right + hpad
        width = self.rbAnneal.defaultWidth
        height = self.rbAnneal.defaultHeight

      # Anneal contents
      self.stStrat:
        top = self.sbAnneal.top + boxvspc
        left = self.sbAnneal.left + hpad
        width = self.stStrat.defaultWidth
        height = self.stStrat.defaultHeight
      self.rbStrat1:
        top = self.stStrat.bottom
        left = self.sbAnneal.left + hpad
        width = self.rbStrat1.defaultWidth
        height = self.rbStrat1.defaultHeight
      self.rbStrat2:
        top = self.rbStrat1.bottom
        left = self.sbAnneal.left + hpad
        width = self.rbStrat2.defaultWidth
        height = self.rbStrat2.defaultHeight

      self.stReplFn:
        top = self.sbAnneal.top + boxvspc
        left = self.rbStrat1.right + hspc * 2
        width = self.stReplFn.defaultWidth
        height = self.stReplFn.defaultHeight
      self.rbWiggle:
        top = self.stReplFn.bottom
        left = self.stReplFn.left
        width = self.rbWiggle.defaultWidth
        height = self.rbWiggle.defaultHeight
      self.rbSwap:
        top = self.rbWiggle.bottom
        left = self.stReplFn.left
        width = self.rbSwap.defaultWidth
        height = self.rbSwap.defaultHeight

      self.stStartTemp:
        top = self.rbStrat2.bottom + vpad
        left = self.sbAnneal.left + hpad
        width = self.stStartTemp.defaultWidth
        height = self.stStartTemp.defaultHeight
      self.slTemp:
        top = self.stStartTemp.bottom
        left = self.sbAnneal.left + hpad
        height = self.slTemp.defaultHeight
        right = self.stStartTempNum.left
      self.stStartTempNum:
        bottom = self.slTemp.bottom
        right = self.stReplFn.right
        width = self.stStartTempNum.defaultWidth
        height = self.stStartTempNum.defaultHeight
      self.stCurrTemp:
        top = self.slTemp.bottom
        left = self.sbAnneal.left + hpad
        width = self.stCurrTemp.defaultWidth
        height = self.stCurrTemp.defaultHeight
      self.stCurrTempNum:
        bottom = self.stCurrTemp.bottom
        left = self.stCurrTemp.right + hpad
        width = self.stCurrTempNum.defaultWidth
        height = self.stCurrTempNum.defaultHeight
      self.cbMonitor:
        top = self.stCurrTemp.bottom
        left = self.sbAnneal.left + hpad
        width = self.cbMonitor.defaultWidth
        height = self.cbMonitor.defaultHeight

      # Done and Undo buttons
      self.bDone:
        bottom = self.height - vmarg
        right = self.right - hmarg
        width = buttWidth
        height = buttHeight
      self.bUndo:
        bottom = self.height - vmarg
        right = self.bDone.left - hspc
        width = buttWidth
        height = buttHeight
  
  proc onResize(self: wPlacementPanel) =
    self.layout()

  proc barHeight(self: wPlacementPanel): int =
    self.dpiScale(buttHeightRaw + 2 * vmargRaw)

  proc onPaint(self: wPlacementPanel, event: wEvent) =
    var dc = PaintDC(self)
    let
      sz = self.size
      barheight = self.barHeight()

    # Rectangle behind button
    dc.setBrush(Brush(doneAreaColor.wColor))
    dc.setPen(Pen(doneAreaColor.wColor))
    dc.drawRectangle(0, sz.height - barheight, sz.width, barheight)

  proc requiredSize(self: wPlacementPanel): wSize =
    # After layout() has positioned everything, find the true extent
    var maxRight, maxBottom: int
    for ctrl in [self.sbAnneal]:  # whichever controls define the outer boundary
      maxRight = max(maxRight, ctrl.position.x + ctrl.size.width)
      maxBottom = max(maxBottom, ctrl.position.y + ctrl.size.height)
    result = (maxRight + self.dpiScale(hmargRaw),
              maxBottom + self.barHeight() + self.dpiScale(vmargRaw))

  proc init*(self: wPlacementPanel, parent: wWindow) =
    wPanel(self).init(parent)
    self.backgroundColor = panelBackgroundColor
    # Create controls
    # Static Boxes
    self.sbBoundReg      = StaticBox(self, label="Bounding Region")
    self.sbCompactMethod = StaticBox(self, label="Compact Method")
    self.sbAnneal        = StaticBox(self, label="Anneal Options")
    self.sbMinSpacing    = StaticBox(self, label="Minimum Spacing")
    self.sbOrder         = StaticBox(self, label="Compact Order")

    # Static Texts
    self.stQty          = StaticText(self, label="Qty")
    self.stSelected     = StaticText(self, label="Selected")
    self.stSelectedNum  = StaticText(self, label="0")
    self.stCompTitle    = StaticText(self, label="Compact In Region")
    self.stX            = StaticText(self, label="X")
    self.stY            = StaticText(self, label="Y")
    self.stW            = StaticText(self, label="W")
    self.stH            = StaticText(self, label="H")
    self.stMinX         = StaticText(self, label="X")
    self.stMinY         = StaticText(self, label="Y")
    self.stStrat        = StaticText(self, label="Strategy")
    self.stReplFn       = StaticText(self, label="Replacement Function")
    self.stStartTemp    = StaticText(self, label="Start Temp")
    self.stStartTempNum = StaticText(self, label="25")
    self.stCurrTemp     = StaticText(self, label="Current Temp")
    self.stCurrTempNum  = StaticText(self, label="25")
    
    # Text Controls
    self.tcQty      = TextCtrl(self, style=wBorderSimple)
    self.tcX        = TextCtrl(self, style=wBorderSimple)
    self.tcY        = TextCtrl(self, style=wBorderSimple)
    self.tcW        = TextCtrl(self, style=wBorderSimple)
    self.tcH        = TextCtrl(self, style=wBorderSimple)
    self.tcMinX     = TextCtrl(self, style=wBorderSimple)
    self.tcMinY     = TextCtrl(self, style=wBorderSimple)
      
    # Buttons
    self.bRandomizeAll = Button(self, label="Randomize All")
    self.bRandomizePos = Button(self, label="Randomize Pos")
    self.bTest         = Button(self, label="Test")
    self.bBoundReg     = Button(self, label="Draw Region")
    self.bLeft         = Button(self)
    self.bRight        = Button(self)
    self.bUp           = Button(self)
    self.bDown         = Button(self)
    self.bUpLeft       = Button(self)
    self.bUpRight      = Button(self)
    self.bDnLeft       = Button(self)
    self.bDnRight      = Button(self)
    self.bUndo         = Button(self, label="Undo")
    self.bDone         = Button(self, label="Done")

    # Radio Buttons
    self.rbNone   = RadioButton(self, label="None")
    self.rbStack  = RadioButton(self, label="Stack")
    self.rbAnneal = RadioButton(self, label="Anneal")
    self.rbStrat1 = RadioButton(self, label="Strat1")
    self.rbStrat2 = RadioButton(self, label="Strat2")
    self.rbWiggle = RadioButton(self, label="Wiggle")
    self.rbSwap   = RadioButton(self, label="Swap")
    self.rbHV     = RadioButton(self, label="Horiz then Vert")
    self.rbVH     = RadioButton(self, label="Vert then Horiz")

    # Slider
    self.slTemp = Slider(self)

    # Checkbox
    self.cbMonitor = CheckBox(self, label="Monitor Progress")

    # Configure
    let titleFace = "Segoe UI"
    self.stSelectedNum.font = Font(faceName=titleFace, pointSize=12)
    self.stCompTitle.font = Font(faceName=titleFace, pointSize=14, weight=wFontWeightBold)
    self.stStartTempNum.font = Font(faceName=titleFace, pointSize=12)
    self.stCurrTempNum.font = Font(faceName=titleFace, pointSize=12)
    let iconSz = appDpiScale((iconSizeRaw, iconSizeRaw))
    self.bUpLeft.setBitmap (svgToBitmap(icons["upleft" ], iconSz))
    self.bUp.setBitmap     (svgToBitmap(icons["up"     ], iconSz))
    self.bUpRight.setBitmap(svgToBitmap(icons["upright"], iconSz))
    self.bLeft.setBitmap   (svgToBitmap(icons["left"   ], iconSz))
    self.bRight.setBitmap  (svgToBitmap(icons["right"  ], iconSz))
    self.bDown.setBitmap   (svgToBitmap(icons["down"   ], iconSz))
    self.bDnLeft.setBitmap (svgToBitmap(icons["dnleft" ], iconSz))
    self.bDnRight.setBitmap(svgToBitmap(icons["dnright"], iconSz))

    self.wEvent_Size do (event: wEvent): self.onResize()
    self.wEvent_Paint do (event: wEvent): self.onPaint(event)


wClass(wPlacementFrame of wFrame):
  proc onDestroy(self: wPlacementFrame) =
    sendToListeners(idMsgPlacementFrameClosing, self.mHwnd.WPARAM, 0)

  proc onTimer(self: wPlacementFrame, timerId: int) =
    self.stopTimer(timerId)

  proc init*(self: wPlacementFrame, owner: wWindow, size: wSize) =
    #let style = wModalFrame
    wFrame(self).init(owner, title = "Placement", size=size)#, style = style)
    self.backgroundColor = frameBackgroundColor
    self.mPanel = PlacementPanel(self)
    self.mPanel.layout()
    self.clientSize = self.mPanel.requiredSize
    # Respond generic events
    self.wEvent_Close do(): self.onDestroy()
    self.wEvent_Timer do(): self.onTimer(1)
    self.startTimer(0.0, id=1) # one-shot to start



when isMainModule:
  import jsoninit
  try:
    jsonInitGlobals()
    wSetSystemDPIAware()
    let
      app = App()
      f1 = PlacementFrame(nil, appDpiScale((1200, 600)))
    f1.show()
    app.mainLoop()
  except Exception as e:
    echo e.msg
    echo e.getStackTrace()
