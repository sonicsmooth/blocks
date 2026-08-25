import std/[sugar, 
            strutils,
            strformat,
            tables,
            parseutils]
import wNim
import winim

import grid
import routing
import utils
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
    stQty, stSelected, stCompTitle, 
      stX, stY, stW, stH, stMinX, stMinY,
      stStrat, stReplFn, stStartTemp,
      stStartTempNum, stCurrTemp, stCurrTempNum: wStaticText
    
    # Text Controls
    tcQty, tcSelected, tcX, tcY, tcW, tcH,
      tcMinX, tcMinY: wTextCtrl

    # Buttons
    bRandomizeAll, bRandomizePos, bTest, bBoundReg,
      bLeft, bRight, bUp, bDown,
      bUpLeft, bUpRight, bDnLeft, bDnRight: wButton

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
  buttonAreaColor = 0xe4e4e4 #0xf0f0f0
  pth = r"../../icons/claude/icons/ico/"
  res = [(name: "up",      data: staticRead(pth & r"arrow_up.ico"        )),
         (name: "down",    data: staticRead(pth & r"arrow_down.ico"      )),
         (name: "left",    data: staticRead(pth & r"arrow_left.ico"      )),
         (name: "right",   data: staticRead(pth & r"arrow_right.ico"     )),
         (name: "upleft",  data: staticRead(pth & r"arrow_up_left.ico"   )),
         (name: "upright", data: staticRead(pth & r"arrow_up_right.ico"  )),
         (name: "dnleft",  data: staticRead(pth & r"arrow_down_left.ico" )),
         (name: "dnright", data: staticRead(pth & r"arrow_down_right.ico"))]
  iconSize = 64
var
  icons: Table[string, wTypes.wIcon]

for (name, data) in res:
  icons[name] = Icon(data, (iconSize, iconSize))

proc moveby(w: wWindow, dx, dy: int) =
  w.position = (w.position.x + dx, w.position.y + dy)

proc parseNumber[T](s: string, number: var T): bool =
  # Returns true if s can be parsed to int or float
  # Parsed value is returned in val
  when T is SomeFloat: parseFloat(s, number) > 0
  elif T is SomeInteger: parseInt(s, number) > 0
  else:
    static: echo "Unsupported WType in parseNumber"
    false

proc errcol(event: wEvent) =
  SetBkColor(event.wParam, RGB(255, 199, 206))
  SetTextColor(event.wParam, RGB(156, 0, 6))

# template layoutAndDump(parent: wResizable, x: untyped) =
#   echo parent.layoutDebug(x)
#   parent.layout(x)

wClass(wPlacementPanel of wPanel):
  proc layout(self: wPlacementPanel) =
    let
      hmarg = self.dpiScale(10) # from panel edge
      vmarg = self.dpiScale(10) # from panel edge
      hpad = self.dpiScale(10) # small spaces
      vpad = self.dpiScale(10) # small spaces
      hspc = self.dpiScale(14) # larger spaces
      vspc = self.dpiScale(10) # larger spaces
      boxvspc = self.dpiScale(20) # down from top of static box to avoid text
      vgap = self.dpiScale(4) # tiny space
      bbTxtAdjust = self.dpiScale(8) # get top compass buttons to align with box line not text
      buttWidth = self.dpiScale(120)
      buttHeight = self.dpiScale(30)
      arrowBtnSize = self.dpiScale(40)
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
      self.tcSelected:
        left = self.stSelected.right
        centerY = self.bRandomizeAll.centerY
        width = txtCtrlWidth
        height = self.tcSelected.defaultHeight
      self.bRandomizeAll:
        right = self.bRandomizePos.left - hspc
        top = self.top + vmarg
        width = buttWidth
        height = buttHeight
        left >= self.tcQty.right + hspc
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
        bottom >= self.tcX.bottom + vpad
        bottom >= self.bDown.bottom
        right >= self.tcH.right + hpad # temporary
      self.sbMinSpacing:
        left = self.bLeft.left
        top = self.bDown.bottom + vspc
        bottom = self.sbAnneal.bottom
        bottom >= self.tcMinY.bottom + vpad
        right >= self.tcMinY.right + hpad
        width = self.sbOrder.width
      self.sbOrder:
        left = self.sbMinSpacing.right + hspc
        top = self.sbMinSpacing.top
        bottom = self.sbAnneal.bottom
        bottom >= self.rbVH.bottom + vpad
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
        left >= self.stStrat.right + hspc
        left >= self.rbStrat1.right + hspc
        left >= self.rbStrat2.right + hspc
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
        right = self.stReplFn.right
      self.stStartTempNum:
        bottom = self.slTemp.bottom
        left = self.slTemp.right
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



        

      
   

  proc onResize(self: wPlacementPanel) =
    self.layout()

  proc onPaint(self: wPlacementPanel, event: wEvent) =
    var dc = PaintDC(self)
    let
      sz = self.size
      buttHeight = self.dpiScale(24)
      barheight = buttHeight + self.dpiScale(28)

    # Rectangle behind button
    dc.setBrush(Brush(buttonAreaColor.wColor))
    dc.setPen(Pen(buttonAreaColor.wColor))
    dc.drawRectangle(0, sz.height - barheight, sz.width, barheight)



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
    self.tcSelected = TextCtrl(self, style=wBorderSimple)
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
    self.stCompTitle.font = Font(faceName=titleFace, pointSize=14, weight=wFontWeightBold)
    self.stStartTempNum.font = Font(faceName=titleFace, pointSize=12)
    self.stCurrTempNum.font = Font(faceName=titleFace, pointSize=12)
    self.bUpLeft.setIcon(icons["upleft"])
    self.bUp.setIcon(icons["up"])
    self.bUpRight.setIcon(icons["upright"])
    self.bLeft.setIcon(icons["left"])
    self.bRight.setIcon(icons["right"])
    self.bDown.setIcon(icons["down"])
    self.bDnLeft.setIcon(icons["dnleft"])
    self.bDnRight.setIcon(icons["dnright"])

    self.wEvent_Size do (event: wEvent): self.onResize()
    self.wEvent_Paint do (event: wEvent): self.onPaint(event)

proc appDpiScale(value: wSize): wSize =
  let d = wAppGetDpi()
  (value.width * d div 96, value.height * d div 96)

proc appDpiScale(value: int): int =
  value * wAppGetDpi() div 96

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
    self.marginLeft  = appDpiScale(4)
    self.marginRight = appDpiScale(4)
    self.marginUp    = appDpiScale(4)
    self.marginDown  = appDpiScale(0)
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
