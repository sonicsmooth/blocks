
from std/strutils import strip
import std/tables

import wNim
import winim
import winim/inc/winuser

import icons
import pubsub
import utils
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
      stCompTitle, stDrawRegion,
      stX, stY, stW, stH,
      stMinX, stMinY, stStrat, stReplFn,
      stStartTemp, stStartTempNum,
      stCurrTemp, stCurrTempNum: wStaticText
    
    # Text Controls
    txtQty, txtX, txtY, txtW, txtH,
      txtMinX, txtMinY: wTextCtrl

    # Buttons
    bRandomizeAll, bRandomizePos, bTest, #bBoundReg,
      bLeft, bRight, bUp, bDown,
      bLeftUp, bRightUp, bLeftDown, bRightDown,
      bUndo, bDone: wButton

    # Radio buttons
    rbNone, rbStack, rbAnneal, rbStrat1, rbStrat2, 
      rbWiggle, rbSwap, rbHV, rbVH: wRadioButton

    # Other
    slStartTemp: wSlider
    cbMonitor: wCheckBox
    cbDrawRegion: wCheckBox

    # iconTable: Table[wTypes.wButton, string]


  wPlacementFrame* = ref object of wFrame
    mPanel: wPlacementPanel

const
  frameBackgroundColor = 0xd0d0d0
  panelBackgroundColor = 0xf0f0f0
  doneAreaColor = 0xe4e4e4 #0xf0f0f0
  buttHeightRaw = 30
  buttWidthRaw = 110
  iconSizeRaw = 40
  txtCtrlWidthRaw = 60
  hmargRaw = 12 # distance from edge
  vmargRaw = 12
  hpadRaw = 12 
  vpadRaw = 12
  hspcRaw = 18 # Distance between group boxes
  vspcRaw = 14
  vgapRaw = 4
  # bigDescentRaw = 4 # fudged until it looks ok
  fontSizeSmall = 9
  fontSizeMed = 12
  fontSizeLarge = 16

proc fontDescent(font: wFont): int =
  let hdc = GetDC(0)
  let old = SelectObject(hdc, font.getHandle())
  var tm: TEXTMETRICW
  discard GetTextMetricsW(hdc, addr tm)
  discard SelectObject(hdc, old)
  discard ReleaseDC(0, hdc)
  result = tm.tmDescent

proc appDpiScale(value: wSize): wSize =
  let d = wAppGetDpi()
  (value.width * d div 96, value.height * d div 96)

proc appDpiScale(value: int): int =
  value * wAppGetDpi() div 96

proc errcol(event: wEvent) =
  SetBkColor(event.wParam, RGB(255, 199, 206))
  SetTextColor(event.wParam, RGB(156, 0, 6))

proc setBitmap(ctrl: wCheckBox, bmp: wBitmap) =
  discard SendMessage(ctrl.handle, BM_SETIMAGE, IMAGE_BITMAP.WPARAM, bmp.handle.LPARAM)

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
      txtCtrlWidth = self.dpiScale(txtCtrlWidthRaw)
      offset = fontDescent(self.stCurrTempNum.font) - fontDescent(self.stCurrTemp.font)
      startTempNumExtraOne = self.dpiScale(10)

    self.stCompTitle.fit()
    self.stSelected.fit()
    self.stCurrTempNum.fit()
    self.layout:
      # Top Row
      self.stQty:
        left = self.left + hmarg
        centerY = self.bRandomizeAll.centerY
        width = self.stQty.defaultWidth
        height = self.stQty.defaultHeight
      self.txtQty:
        left = self.stQty.right
        centerY = self.bRandomizeAll.centerY
        width = txtCtrlWidth
        height = self.txtQty.defaultHeight
      self.stSelected:
        left = self.txtQty.right + hspc
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
      self.bLeftUp:
        top = self.stCompTitle.bottom + bbTxtAdjust
        left = self.left + hmarg
        width = arrowBtnSize
        height = arrowBtnSize
      self.bUp:
        top = self.stCompTitle.bottom + bbTxtAdjust
        left = self.bLeftUp.right
        width = arrowBtnSize
        height = arrowBtnSize
      self.bRightUp:
        top = self.stCompTitle.bottom + bbTxtAdjust
        left = self.bUp.right
        width = arrowBtnSize
        height = arrowBtnSize
      self.bLeft:
        top = self.bLeftUp.bottom
        left = self.bLeftUp.left
        width = arrowBtnSize
        height = arrowBtnSize
      self.bRight:
        top = self.bRightUp.bottom
        left = self.bRightUp.left
        width = arrowBtnSize
        height = arrowBtnSize
      self.bLeftDown:
        top = self.bLeft.bottom
        left = self.bLeft.left
        width = arrowBtnSize
        height = arrowBtnSize
      self.bDown:
        top = self.bLeft.bottom
        left = self.bLeftDown.right
        width = arrowBtnSize
        height = arrowBtnSize
      self.bRightDown:
        top = self.bRight.bottom
        left = self.bDown.right
        width = arrowBtnSize
        height = arrowBtnSize

      # Static Boxes, Left
      self.sbBoundReg:
        top = self.stCompTitle.bottom
        left = self.bRightUp.right + hspc
        bottom = self.bDown.bottom
        right >= self.txtH.right + hpad
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
      self.cbDrawRegion:
        top = self.sbBoundReg.top + boxvspc
        #left = self.sbBoundReg.left + hpad
        left = self.stDrawRegion.right + hpad
        width = arrowBtnSize
        height = arrowBtnSize
      self.stDrawRegion:
        centerY = self.cbDrawRegion.centerY
        left = self.sbBoundReg.left + hpad
        width = self.stDrawRegion.defaultWidth
        height = self.stDrawRegion.defaultHeight

      self.stX:
        top = self.cbDrawRegion.bottom + vpad
        left = self.sbBoundReg.left + hpad
        width = self.stX.defaultWidth
        height = self.stX.defaultHeight
      self.stY:
        top = self.cbDrawRegion.bottom + vpad
        left = self.txtX.right + hpad
        width = self.stY.defaultWidth
        height = self.stY.defaultHeight
      self.stW:
        top = self.cbDrawRegion.bottom + vpad
        left = self.txtY.right + hpad
        width = self.stW.defaultWidth
        height = self.stW.defaultHeight
      self.stH:
        top = self.cbDrawRegion.bottom + vpad
        left = self.txtW.right + hpad
        width = self.stH.defaultWidth
        height = self.stH.defaultHeight

      self.txtY:
        top = self.stY.bottom
        left = self.stY.left
        width = txtCtrlWidth
        height = self.txtY.defaultHeight
      self.txtX:
        top = self.stX.bottom
        left = self.stX.left
        width = txtCtrlWidth
        height = self.txtX.defaultHeight
      self.txtW:
        top = self.stW.bottom
        left = self.stW.left
        width = txtCtrlWidth
        height = self.txtW.defaultHeight
      self.txtH:
        top = self.stH.bottom
        left = self.stH.left
        width = txtCtrlWidth
        height = self.txtW.defaultHeight

      # Minimum Spacing contents
      self.txtMinX:
        top = self.sbMinSpacing.top + boxvspc
        left = self.stMinX.right
        width = txtCtrlWidth
        height = self.txtMinX.defaultHeight
      self.txtMinY:
        top = self.txtMinX.bottom + vgap
        left = self.txtMinX.left
        width = txtCtrlWidth
        height = self.txtMinY.defaultHeight
      self.stMinX:
        bottom = self.txtMinX.bottom
        left = self.sbMinSpacing.left + hpad
        width = self.stMinX.defaultWidth
        height = self.stMinX.defaultHeight
      self.stMiny:
        bottom = self.txtMinY.bottom + vgap
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
      self.slStartTemp:
        top = self.stStartTemp.bottom
        left = self.sbAnneal.left + hpad
        height = self.slStartTemp.defaultHeight
        right = self.stStartTempNum.left
      self.stStartTempNum:
        bottom = self.slStartTemp.bottom - offset
        right = self.stReplFn.right
        width = self.stStartTempNum.defaultWidth + startTempNumExtraOne
        height = self.stStartTempNum.defaultHeight
      self.stCurrTemp:
        bottom = self.stCurrTempNum.bottom - offset
        left = self.sbAnneal.left + hpad
        width = self.stCurrTemp.defaultWidth
        height = self.stCurrTemp.defaultHeight
      self.stCurrTempNum:
        top = self.slStartTemp.bottom
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

  proc onTextFocus(self: wPlacementPanel, event: wEvent) = 
    cast[wTextCtrl](event.window).setInsertionPointEnd()
    event.skip()

  proc onTextEdit(self: wPlacementPanel, event: wEvent) =
    # var valInt: int
    # var valFloat: WType
    const
      errBg = 0xcec7ff
      errFg = 0x06009c
    let
      txtCtrl = cast[wTextCtrl](event.window)
      valInt = parseNumber[int](txtCtrl.value.strip())
      valFloat = parseNumber[float](txtCtrl.value.strip())

    if txtCtrl == self.txtQty and valInt.isSome():
      txtCtrl.backgroundColor = 0xffffff
      txtCtrl.foregroundColor = 0x000000
    elif txtCtrl == self.txtQty and not valInt.isSome():
      txtCtrl.backgroundColor = errBg
      txtCtrl.foregroundColor = errFg
    elif txtCtrl in @[self.txtX, self.txtY, self.txtW, self.txtH, self.txtMinX, self.txtMinY] and valFloat.isSome():
      txtCtrl.backgroundColor = 0xffffff
      txtCtrl.foregroundColor = 0x000000
    else:
      txtCtrl.backgroundColor = errBg
      txtCtrl.foregroundColor = errFg

  proc onTextCommit(self: wPlacementPanel, event: wEvent) =
    # Only qty, x, y, w, h need to get sent when text is entered
    # min spacing is sent with the arrow buttons
    let txtCtrl = cast[wTextCtrl](event.window)
    let valInt = parseNumber[int](txtCtrl.value.strip())
    let valFloat = parseNumber[float](txtCtrl.value.strip())

    if valInt.isSome() and txtCtrl == self.txtQty:
      sendToListeners(idPlcTxtQtySend, self.handle.WPARAM, valInt.get().LPARAM)
      echo "Comitted: ", valInt.get()
    elif valFloat.isSome() and txtCtrl in @[self.txtX, self.txtY, self.txtW, self.txtH]:
      let floatBits = cast[uint64](valFloat.get())
      var msgId: uint32
      if   txtCtrl == self.txtX:  msgId = idPlcTxtXSend
      elif txtCtrl == self.txtY:  msgId = idPlcTxtYSend
      elif txtCtrl == self.txtW:  msgId = idPlcTxtWSend
      elif txtCtrl == self.txtH:  msgId = idPlcTxtHSend
      sendToListeners(msgId, self.handle.WPARAM, floatBits.LPARAM)
      echo "Commited: ", valFloat.get()
    else:
      echo "not commiting: ", txtCtrl.value

  proc onKillFocus(self: wPlacementPanel, event: wEvent) =
    self.onTextCommit(event)
    event.skip()

  proc onButtonRandomizeAll(self: wPlacementPanel) =
    echo "button rand all"
    gPubSubCompactButtons.publish(woPlcTest, BtnRandAll)
    # sendToListeners(idPlcRandomAll, self.handle.WPARAM, 0)

  proc onButtonRandomizePos(self: wPlacementPanel) =
    echo "button rand pos"
    gPubSubCompactButtons.publish(woPlcTest, BtnRandPos)
    # sendToListeners(idPlcRandomPos, self.handle.WPARAM, 0)
  proc onButtonTest(self: wPlacementPanel) =
    echo "button test"
    gPubSubCompactButtons.publish(woPlcTest, BtnTest)
    # sendToListeners(idPlcTest, self.handle.WPARAM, 0)
  
  proc onCheckBoxDrawRegion(self: wPlacementPanel, event: wEvent) =
    let drawSz = appDpiScale((iconSizeRaw, iconSizeRaw))
    if self.cbDrawRegion.value:
      echo "clicked"
      self.cbDrawRegion.setBitmap(iconBitmap("drag", drawSz, Pressed))
    else:
      echo "unclicked"
      self.cbDrawRegion.setBitmap(iconBitmap("drag", drawSz, Hover))

  proc onButtonCompactGo(self: wPlacementPanel, event: wEvent) =
    let btn = cast[wButton](event.window)
    var req: CompactRequest

    let dir = 
      if   btn == self.bLeft:  Left
      elif btn == self.bRight: Right
      elif btn == self.bUp:    Up
      elif btn == self.bDown:  Down
      elif btn == self.bLeftUp:
        if self.rbHV.value: LeftUp
        else:               UpLeft
      elif btn == self.bRightUp:
        if self.rbHV.value: RightUp
        else:               UpRight
      elif btn == self.bLeftDown:
        if self.rbHV.value: LeftDown
        else:               DownLeft
      elif btn == self.bRightDown:
        if self.rbHV.value: RightDown
        else:               DownRight
      else:
        raise newException(ValueError, "Invalid window ref")

    req.direction = dir
    var minX, minY: WType
    if not parseNumber(self.txtMinX.value, minX):
      echo "Could not parse ", self.txtMinX.value
      return
    if not parseNumber(self.txtMinY.value, minY):
      echo "Could not parse ", self.txtMinY.value
      return
    req.minSpaceX = minX
    req.minSpaceY = minY
    req.compactMethod = if   self.rbNone.value:  None
                        elif self.rbStack.value: Stack
                        else:                    Anneal
    req.annealStrategy = if self.rbStrat1.value: Strat1
                         else:                   Strat2
    req.replacementFunction = if self.rbWiggle.value: Wiggle
                              else:                   Swap
    req.startTemp = self.slStartTemp.value.float
    req.doMonitor = self.cbMonitor.value
    gPubSubCompactRequest.publish(kCmpCompactReq, req)

  proc updateCompactButton(self: wPlacementPanel, btn: wButton, state: IconState) =
    let iconSz = appDpiScale((iconSizeRaw, iconSizeRaw))
    if   btn == self.bLeft:  btn.setBitmap(iconBitmap("arrow_left" , iconSz, state), wCenter)
    elif btn == self.bRight: btn.setBitmap(iconBitmap("arrow_right", iconSz, state), wCenter)
    elif btn == self.bUp:    btn.setBitmap(iconBitmap("arrow_up",    iconSz, state), wCenter)
    elif btn == self.bDown:  btn.setBitmap(iconBitmap("arrow_down",  iconSz, state), wCenter)
    elif btn == self.bLeftUp:
      if self.rbHV.value: btn.setBitmap(iconBitmap("upper_left_hv_arrow", iconSz, state), wCenter)
      else:               btn.setBitmap(iconBitmap("upper_left_vh_arrow", iconSz, state), wCenter)
    elif btn == self.bRightUp:
      if self.rbHV.value: btn.setBitmap(iconBitmap("upper_right_hv_arrow", iconSz, state), wCenter)
      else:               btn.setBitmap(iconBitmap("upper_right_vh_arrow", iconSz, state), wCenter)
    elif btn == self.bLeftDown:
      if self.rbHV.value: btn.setBitmap(iconBitmap("lower_left_hv_arrow", iconSz, state), wCenter)
      else:               btn.setBitmap(iconBitmap("lower_left_vh_arrow", iconSz, state), wCenter)
    elif btn == self.bRightDown:
      if self.rbHV.value: btn.setBitmap(iconBitmap("lower_right_hv_arrow", iconSz, state), wCenter)
      else:               btn.setBitmap(iconBitmap("lower_right_vh_arrow", iconSz, state), wCenter)

  proc onButtonMouseEnterLeave(self: wPlacementPanel, event: wEvent) =
    let btn = cast[wButton](event.window)
    let iconSz = appDpiScale((iconSizeRaw, iconSizeRaw))
    let state = if event.eventType == wEvent_MouseEnter: Hover else: Normal
    self.updateCompactButton(btn, state)
    event.skip()

  proc onButtonMouseClick(self: wPlacementPanel, event: wEvent) =
    let btn = cast[wButton](event.window)
    let iconSz = appDpiScale((iconSizeRaw, iconSizeRaw))
    let state = if event.eventType == wEvent_LeftDown: Pressed else: Hover
    self.updateCompactButton(btn, state)
    event.skip()

  proc onButtonUndo(self: wPlacementPanel) =
    echo "button undo"
  proc onButtonDone(self: wPlacementPanel) =
    echo "button done"
  proc onMethodRadioButton(self: wPlacementPanel, event: wEvent) =
    if self.rbNone.value or self.rbStack.value: # No strategy
      self.sbAnneal.disable()
      self.stStrat.disable()
      self.stReplFn.disable()
      self.stStartTemp.disable()
      self.stStartTempNum.disable()
      self.stCurrTemp.disable()
      self.stCurrTempNum.disable()
      self.rbStrat1.disable()
      self.rbStrat2.disable()
      self.rbWiggle.disable()
      self.rbSwap.disable()
      self.slStartTemp.disable()
      self.cbMonitor.disable()
    elif self.rbAnneal.value: # Anneal
      self.sbAnneal.enable()
      self.stStrat.enable()
      self.stReplFn.enable()
      self.stStartTemp.enable()
      self.stStartTempNum.enable()
      self.stCurrTemp.enable()
      self.stCurrTempNum.enable()
      self.rbStrat1.enable()
      self.rbStrat2.enable()
      self.rbWiggle.enable()
      self.rbSwap.enable()
      self.slStartTemp.enable()
      self.cbMonitor.enable()
  proc onOptionsRadioButton(self: wPlacementPanel, event: wEvent) =
    echo "radio button options"
  proc onOrderRadioButton(self: wPlacementPanel, event: wEvent) =
    self.updateCompactButton(self.bLeftUp,    Normal)
    self.updateCompactButton(self.bRightUp,   Normal)
    self.updateCompactButton(self.bLeftDown,  Normal)
    self.updateCompactButton(self.bRightDown, Normal)

  proc onTempSlider(self: wPlacementPanel) =
    self.stStartTempNum.label = $self.slStartTemp.value
  proc onMonitorCheckBox(self: wPlacementPanel, event: wEvent) =
    echo "monitor checkbox"

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
    self.stDrawRegion   = StaticText(self, label="Draw Region")
    self.stX            = StaticText(self, label="X")
    self.stY            = StaticText(self, label="Y")
    self.stW            = StaticText(self, label="W")
    self.stH            = StaticText(self, label="H")
    self.stMinX         = StaticText(self, label="X")
    self.stMinY         = StaticText(self, label="Y")
    self.stStrat        = StaticText(self, label="Strategy")
    self.stReplFn       = StaticText(self, label="Replacement Function")
    
    self.stStartTemp    = StaticText(self, label="Start Temp")
    self.stStartTempNum = StaticText(self, label="xx", style=wAlignRight)
    self.stCurrTemp     = StaticText(self, label="Current Temp")
    self.stCurrTempNum  = StaticText(self, label="")
    
    # Text Controls
    self.txtQty      = TextCtrl(self, style=wBorderSimple)
    self.txtX        = TextCtrl(self, style=wBorderSimple)
    self.txtY        = TextCtrl(self, style=wBorderSimple)
    self.txtW        = TextCtrl(self, style=wBorderSimple)
    self.txtH        = TextCtrl(self, style=wBorderSimple)
    self.txtMinX     = TextCtrl(self, style=wBorderSimple)
    self.txtMinY     = TextCtrl(self, style=wBorderSimple)
      
    # Buttons
    self.bRandomizeAll = Button(self, label="Randomize All")
    self.bRandomizePos = Button(self, label="Randomize Pos")
    self.bTest         = Button(self, label="Test")
    self.cbDrawRegion    = Checkbox(self, label="xxx", style=BS_PUSHLIKE or BS_BITMAP)
    self.bLeft         = Button(self, style=BS_BITMAP)
    self.bRight        = Button(self, style=BS_BITMAP)
    self.bUp           = Button(self, style=BS_BITMAP)
    self.bDown         = Button(self, style=BS_BITMAP)
    self.bLeftUp       = Button(self, style=BS_BITMAP)
    self.bRightUp      = Button(self, style=BS_BITMAP)
    self.bLeftDown     = Button(self, style=BS_BITMAP)
    self.bRightDown    = Button(self, style=BS_BITMAP)
    self.bUndo         = Button(self, label="Undo")
    self.bDone         = Button(self, label="Done")

    # Radio Buttons
    self.rbNone   = RadioButton(self, label="None", style=wRbGroup)
    self.rbStack  = RadioButton(self, label="Stack")
    self.rbAnneal = RadioButton(self, label="Anneal")
    self.rbStrat1 = RadioButton(self, label="Strat1", style=wRbGroup)
    self.rbStrat2 = RadioButton(self, label="Strat2")
    self.rbWiggle = RadioButton(self, label="Wiggle", style=wRbGroup)
    self.rbSwap   = RadioButton(self, label="Swap")
    self.rbHV     = RadioButton(self, label="Horiz then Vert", style=wRbGroup)
    self.rbVH     = RadioButton(self, label="Vert then Horiz")

    # Slider
    self.slStartTemp = Slider(self)

    # Checkbox
    self.cbMonitor = CheckBox(self, label="Monitor Progress")

    # Configure
    let titleFace = "Segoe UI"
    # Let "medium" be the default size, so change some elements to large or smal
    self.stCompTitle.font    = Font(pointSize=fontSizeLarge, weight=wFontWeightBold)
    self.stStrat.font        = Font(pointSize=fontSizeSmall)
    self.stReplFn.font       = Font(pointSize=fontSizeSmall)
    self.stStartTempNum.font = Font(pointSize=fontSizeLarge)
    self.stCurrTempNum.font  = Font(pointSize=fontSizeLarge)
    # Update arrow buttons down below after the radio buttons are clicked, so they have the right icon
    let iconSz = appDpiScale((iconSizeRaw, iconSizeRaw))
    self.cbDrawRegion.setBitmap(iconBitmap("drag", iconSz))
   
    # Respond to generic events
    self.wEvent_Size do (event: wEvent): self.onResize()
    self.wEvent_Paint do (event: wEvent): self.onPaint(event)

    # Respond to controls
    # Text Controls
    let ctls = @[self.txtQty, self.txtX, self.txtY, self.txtW, self.txtH,
                 self.txtMinX, self.txtMinY]
    for ctl in ctls:
      ctl.wEvent_SetFocus  do (event: wEvent): self.onTextFocus(event)
      ctl.wEvent_Text      do (event: wEvent): self.onTextEdit(event)
      ctl.wEvent_TextEnter do (event: wEvent): self.onTextCommit(event)
      ctl.wEvent_KillFocus do (event: wEvent): self.onKillFocus(event)
      # self.WM_CTLCOLOREDIT do (event: wEvent): self.colorEdit(event)
      
    # Buttons
    self.bRandomizeAll.wEvent_Button do (): self.onButtonRandomizeAll()
    self.bRandomizePos.wEvent_Button do (): self.onButtonRandomizePos()
    self.bTest.wEvent_Button         do (): self.onButtonTest()
    for btn in @[self.bLeft, self.bRight, self.bUp, self.bDown,
                 self.bLeftUp, self.bRightUp, self.bLeftDown, self.bRightDown]:
      btn.wEvent_Button     do (event: wEvent): self.onButtonCompactGo(event)
      btn.wEvent_MouseEnter do (event: wEvent): self.onButtonMouseEnterLeave(event)
      btn.wEvent_MouseLeave do (event: wEvent): self.onButtonMouseEnterLeave(event)
      btn.wEvent_LeftDown   do (event: wEvent): self.onButtonMouseClick(event)
      btn.wEvent_LeftUp     do (event: wEvent): self.onButtonMouseClick(event)
    self.bUndo.wEvent_Button do (): self.onButtonUndo()
    self.bDone.wEvent_Button do (): self.onButtonDone()

    # Radio Buttons
    self.rbNone.wEvent_RadioButton   do (event: wEvent): self.onMethodRadioButton(event)
    self.rbStack.wEvent_RadioButton  do (event: wEvent): self.onMethodRadioButton(event)
    self.rbAnneal.wEvent_RadioButton do (event: wEvent): self.onMethodRadioButton(event)
    self.rbStrat1.wEvent_RadioButton do (event: wEvent): self.onOptionsRadioButton(event)
    self.rbStrat2.wEvent_RadioButton do (event: wEvent): self.onOptionsRadioButton(event)
    self.rbWiggle.wEvent_RadioButton do (event: wEvent): self.onOptionsRadioButton(event)
    self.rbSwap.wEvent_RadioButton   do (event: wEvent): self.onOptionsRadioButton(event)
    self.rbHV.wEvent_RadioButton     do (event: wEvent): self.onOrderRadioButton(event)
    self.rbVH.wEvent_RadioButton     do (event: wEvent): self.onOrderRadioButton(event)

    # Slider
    self.slStartTemp.wEvent_Slider do (): self.onTempSlider()

    # Checkbox
    self.cbDrawRegion.wEvent_CheckBox do (event: wEvent): self.onCheckBoxDrawRegion(event)
    self.cbMonitor.wEvent_Checkbox do (event: wEvent): self.onMonitorCheckBox(event)

    # Click on the radio buttons to set initial state, set qty and slider
    self.txtQty.value = "10"
    self.txtX.value = "30"
    self.txtY.value = "30"
    self.txtW.value = "500"
    self.txtH.value = "500"
    self.txtMinX.value = "2"
    self.txtMinY.value = "2"
    self.rbNone.click()
    self.rbStrat1.click()
    self.rbWiggle.click()
    self.rbHV.click()
    self.slStartTemp.setRange(1, 100)
    self.slStartTemp.value = 50
    self.stStartTempNum.label = $self.slStartTemp.value

    # Finally update buttons to have the right icon for the current radio button state
    self.updateCompactButton(self.bLeft,      Normal)
    self.updateCompactButton(self.bRight,     Normal)
    self.updateCompactButton(self.bUp,        Normal)
    self.updateCompactButton(self.bDown,      Normal)
    self.updateCompactButton(self.bLeftUp,    Normal)
    self.updateCompactButton(self.bRightUp,   Normal)
    self.updateCompactButton(self.bLeftDown,  Normal)
    self.updateCompactButton(self.bRightDown, Normal)






wClass(wPlacementFrame of wFrame):
  proc onDestroy(self: wPlacementFrame) =
    sendToListeners(idPlcFrameClosing, self.handle.WPARAM, 0)

  proc init*(self: wPlacementFrame, owner: wWindow) =
    echo "init start"
    wFrame(self).init(owner, title = "Placement")
    self.backgroundColor = frameBackgroundColor
    self.mPanel = PlacementPanel(self)
    self.mPanel.layout()
    self.clientSize = self.mPanel.requiredSize
    # Respond to generic events
    self.wEvent_Close do(): self.onDestroy()
    echo "done"





when isMainModule:
  # import jsoninit

  proc junkButton(data: CompactButton) = 
    case data:
    of BtnTest:    echo "placement main: testing"
    of BtnRandAll: echo "placement main: rand all"
    of BtnRandPos: echo "placement main: rand pos"

  proc junkRequest(data: CompactRequest) = 
    echo data

  try:
    #jsonInitGlobals()
    wSetSystemDPIAware()
    registerListener(gPubSubCompactButtons, kCmpBtnTest,    junkButton )
    registerListener(gPubSubCompactButtons, kCmpBtnRandAll, junkButton )
    registerListener(gPubSubCompactButtons, kCmpBtnRandPos, junkButton )
    registerListener(gPubSubCompactRequest, kCmpCompactReq, junkRequest)

    let
      app = App()
      f1 = PlacementFrame(nil)
    f1.show()
    app.mainLoop()
  except Exception as e:
    echo e.msg
    echo e.getStackTrace()
