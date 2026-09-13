
import std/os
from std/strutils import strip

import wNim
import winim
import winim/inc/winuser

import icons
import monoprofile
import pubsub
import utils
import uicommon
import routing
import world
import wnimutils

# Create a panel to hold some controls,
# then place it in a frame
type
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
    bRandomizeAll, bRandomizePos, bTest,
      bUndo, bDone: wButton

    # Static images
    bLeft, bRight, bUp, bDown,
      bLeftUp, bRightUp, bLeftDown, bRightDown: wStaticBitmap

    # Radio buttons
    rbNone, rbStack, rbAnneal, rbStrat1, rbStrat2, 
      rbWiggle, rbSwap, rbHV, rbVH: wRadioButton

    # Checkboxes
    cbMonitor, cbDrawRegion: wCheckBox

    # Other
    slStartTemp: wSlider

  wPlacementFrame* = ref object of wFrame
    mPanel: wPlacementPanel


wClass(wPlacementPanel of wPanel):
  proc layout(self: wPlacementPanel) =
    when defined(dumpLayout):
      let
        hmarg = self.dpiScale(gHmargRaw) # from panel edge
        vmarg = self.dpiScale(gVmargRaw) # from panel edge
        hpad = self.dpiScale(gHpadRaw) # small spaces
        vpad = self.dpiScale(gVpadRaw) # small spaces
        hspc = self.dpiScale(gHspcRaw) # larger spaces
        vspc = self.dpiScale(gVspcRaw) # larger spaces
        boxvspc = self.dpiScale(20) # down from top of static box to avoid text
        vgap = self.dpiScale(gVgapRaw) # tiny space
        bbTxtAdjust = self.dpiScale(gTxtVadjust) # get top compass buttons to align with box line not text
        buttWidth = self.dpiScale(gButtWidthRaw)
        buttHeight = self.dpiScale(gButtHeightRaw)
        arrowBtnSize = self.dpiScale(gIconSizeRaw)
        txtCtrlWidth = self.dpiScale(gTxtCtrlWidthRaw)
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
      self.dumpLayout()
    else:
      include "../ui/layouts/wPlacementPanel.layout"

  proc onResize(self: wPlacementPanel) =
    self.layout()

  proc onPaint(self: wPlacementPanel, event: wEvent) =
    var dc = PaintDC(self)
    let sz = self.size
    let bh = barheight()

    # Rectangle behind button
    dc.setBrush(Brush(gButtonAreaColor.wColor))
    dc.setPen(Pen(gButtonAreaColor.wColor))
    dc.drawRectangle(0, sz.height - bh, sz.width, bh)

  proc onDestroy(self: wPlacementPanel) =
    # Clean up pubsub
    when defined(debug):
      echo "PlacementPanel onDestroy"

  proc onTextFocus(self: wPlacementPanel, event: wEvent) = 
    cast[wTextCtrl](event.window).setInsertionPointEnd()
    event.skip()


#   # TODO: redo all parseNumbers
  proc onTextEdit(self: wPlacementPanel, event: wEvent) =
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
      publish(Qty, valInt.get())
      echo "Committed: ", valInt.get()
    elif valFloat.isSome() and txtCtrl in @[self.txtX, self.txtY, self.txtW, self.txtH]:
      if   txtCtrl == self.txtX:  publish(RegionX, valFloat.get())
      elif txtCtrl == self.txtY:  publish(RegionY, valFloat.get())
      elif txtCtrl == self.txtW:  publish(RegionW, valFloat.get())
      elif txtCtrl == self.txtH:  publish(RegionH, valFloat.get())
      echo "Commited: ", valFloat.get()
    else:
      echo "not commiting: ", txtCtrl.value

  proc onKillFocus(self: wPlacementPanel, event: wEvent) =
    self.onTextCommit(event)
    event.skip()

  proc onButtonRandomizeAll(self: wPlacementPanel) =
    publish(RandAll)

  proc onButtonRandomizePos(self: wPlacementPanel) =
    publish(RandPos)
  
  proc onButtonTest(self: wPlacementPanel) =
    publish(Test)
  
  proc onCheckBoxDrawRegion(self: wPlacementPanel, event: wEvent) =
    let drawSz = appDpiScale((gIconSizeRaw, gIconSizeRaw))
    if self.cbDrawRegion.value:
      self.cbDrawRegion.setBitmap(iconBitmap("drag", drawSz, Pressed))
    else:
      self.cbDrawRegion.setBitmap(iconBitmap("drag", drawSz, Hover))

  proc onButtonCompactGo(self: wPlacementPanel, event: wEvent) =
    # let btn = cast[wButton](event.window)
    let btn = cast[wStaticBitmap](event.window)

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

    var minX, minY: WType
    if not parseNumber(self.txtMinX.value, minX):
      echo "Could not parse ", self.txtMinX.value
      return
    if not parseNumber(self.txtMinY.value, minY):
      echo "Could not parse ", self.txtMinY.value
      return
    publish(CompactRequest(
      direction: dir,
      minSpaceX: minX,
      minSpaceY: minY,
      compactMethod: if   self.rbNone.value:  None
                     elif self.rbStack.value: Stack
                     else:                    Anneal,
      annealStrategy: if self.rbStrat1.value: Strat1
                      else:                   Strat2,
      replacementFunction: if self.rbWiggle.value: Wiggle
                           else:                   Swap,
      startTemp: self.slStartTemp.value.float,
      doMonitor: self.cbMonitor.value ))

  proc updateCompactButton(self: wPlacementPanel, btn: wStaticBitmap, state: IconState) =
    let iconSz = appDpiScale((gIconSizeRaw, gIconSizeRaw))
    if   btn == self.bLeft:  btn.setBitmap(iconBitmap("arrow_left" , iconSz, state))
    elif btn == self.bRight: btn.setBitmap(iconBitmap("arrow_right", iconSz, state))
    elif btn == self.bUp:    btn.setBitmap(iconBitmap("arrow_up",    iconSz, state))
    elif btn == self.bDown:  btn.setBitmap(iconBitmap("arrow_down",  iconSz, state))
    elif btn == self.bLeftUp:
      if self.rbHV.value: btn.setBitmap(iconBitmap("upper_left_hv_arrow", iconSz, state))
      else:               btn.setBitmap(iconBitmap("upper_left_vh_arrow", iconSz, state))
    elif btn == self.bRightUp:
      if self.rbHV.value: btn.setBitmap(iconBitmap("upper_right_hv_arrow", iconSz, state))
      else:               btn.setBitmap(iconBitmap("upper_right_vh_arrow", iconSz, state))
    elif btn == self.bLeftDown:
      if self.rbHV.value: btn.setBitmap(iconBitmap("lower_left_hv_arrow", iconSz, state))
      else:               btn.setBitmap(iconBitmap("lower_left_vh_arrow", iconSz, state))
    elif btn == self.bRightDown:
      if self.rbHV.value: btn.setBitmap(iconBitmap("lower_right_hv_arrow", iconSz, state))
      else:               btn.setBitmap(iconBitmap("lower_right_vh_arrow", iconSz, state))

  proc onButtonMouseEnterLeave(self: wPlacementPanel, event: wEvent) =
    let btn = cast[wStaticBitmap](event.window)
    let state = if event.eventType == wEvent_MouseEnter: Hover else: Normal
    self.updateCompactButton(btn, state)
    event.skip()

  proc onButtonMouseClick(self: wPlacementPanel, event: wEvent) =
    # let btn = cast[wButton](event.window)
    let btn = cast[wStaticBitmap](event.window)
    if event.eventType == wEvent_LeftDown:
      self.updateCompactButton(btn, Pressed)
    elif event.eventType == wEvent_LeftUp:
      self.updateCompactButton(btn, Hover)
      self.onButtonCompactGo(event)
    event.skip()

  proc onCheckboxMouseEnterLeave(self: wPlacementPanel, event: wEvent) =
    let cb = cast[wCheckBox](event.window)
    if cb == self.cbDrawRegion:
      let state = if event.eventType == wEvent_MouseEnter: Hover else: Normal
      let drawSz = appDpiScale((gIconSizeRaw, gIconSizeRaw))
      if cb.value:
        cb.setBitmap(iconBitmap("drag", drawSz, Pressed))
      else:
        cb.setBitmap(iconBitmap("drag", drawSz, state))
    event.skip()

  proc onButtonUndo(self: wPlacementPanel) =
    publish(Undo)
  
  proc onButtonDone(self: wPlacementPanel) =
    echo "placementPanel.onButtonDone()"
    # Post message for asynchronous close
    # Otherwise if we do self.parent.close()
    # we get a synchronous close which
    # destroys this button while still in the handler
    discard PostMessage(self.parent.handle, WM_CLOSE, 0, 0)
  
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
    discard
  
  proc onOrderRadioButton(self: wPlacementPanel, event: wEvent) =
    self.updateCompactButton(self.bLeftUp,    Normal)
    self.updateCompactButton(self.bRightUp,   Normal)
    self.updateCompactButton(self.bLeftDown,  Normal)
    self.updateCompactButton(self.bRightDown, Normal)

  proc onTempSlider(self: wPlacementPanel) =
    self.stStartTempNum.label = $self.slStartTemp.value
 
  proc onMonitorCheckBox(self: wPlacementPanel, event: wEvent) =
    discard


  proc init*(self: wPlacementPanel, parent: wWindow) =
    wPanel(self).init(parent)
    self.backgroundColor = gPanelBackgroundColor
    let iconSz = appDpiScale((gIconSizeRaw, gIconSizeRaw))
    block: # Priming cache
      when defined(debug):
        stdout.write "placementframe priming bitmap cache... "
      timeItms(iconProfile, "priming cache placementframe"):
        let iconNames =["arrow_left", "arrow_right", "arrow_up", "arrow_down",
                        "upper_left_hv_arrow", "upper_left_vh_arrow",
                        "upper_right_hv_arrow", "upper_right_vh_arrow",
                        "lower_left_hv_arrow", "lower_left_vh_arrow",
                        "lower_right_hv_arrow", "lower_right_vh_arrow",
                        "drag"]
        initIconBitmaps(iconNames, iconSz)
      when defined(debug):
        stdout.writeLine "done."
    
    block: # Create controls
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
      self.bLeft         = StaticBitmap(self)
      self.bRight        = StaticBitmap(self)
      self.bUp           = StaticBitmap(self)
      self.bDown         = StaticBitmap(self)
      self.bLeftUp       = StaticBitmap(self)
      self.bRightUp      = StaticBitmap(self)
      self.bLeftDown     = StaticBitmap(self)
      self.bRightDown    = StaticBitmap(self)
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

      # Checkboxes
      self.cbDrawRegion = Checkbox(self, label="xxx", style=BS_PUSHLIKE or BS_BITMAP)
      self.cbMonitor    = CheckBox(self, label="Monitor Progress")

    block: # Configure fonts
      # Let "medium" be the default size, so change some elements to large or smal
      self.stCompTitle.font    = Font(pointSize=gFontSizeLarge, weight=wFontWeightBold)
      self.stStrat.font        = Font(pointSize=gFontSizeSmall)
      self.stReplFn.font       = Font(pointSize=gFontSizeSmall)
      self.stStartTempNum.font = Font(pointSize=gFontSizeLarge)
      self.stCurrTempNum.font  = Font(pointSize=gFontSizeLarge)
   
    block: # Respond to generic events
      self.wEvent_Size do (event: wEvent): self.onResize()
      self.wEvent_Paint do (event: wEvent): self.onPaint(event)
      self.wEvent_Destroy do (event: wEvent): self.onDestroy()

    block: # Respond to controls events
      # Text Controls
      let ctls = @[self.txtQty, self.txtX, self.txtY, self.txtW, self.txtH,
                  self.txtMinX, self.txtMinY]
      for ctl in ctls:
        ctl.wEvent_SetFocus  do (event: wEvent): self.onTextFocus(event)
        ctl.wEvent_Text      do (event: wEvent): self.onTextEdit(event)
        ctl.wEvent_TextEnter do (event: wEvent): self.onTextCommit(event)
        ctl.wEvent_KillFocus do (event: wEvent): self.onKillFocus(event)
        
      # Buttons
      self.bRandomizeAll.wEvent_Button do (): self.onButtonRandomizeAll()
      self.bRandomizePos.wEvent_Button do (): self.onButtonRandomizePos()
      self.bTest.wEvent_Button         do (): self.onButtonTest()
      for btn in @[self.bLeft, self.bRight, self.bUp, self.bDown,
                  self.bLeftUp, self.bRightUp, self.bLeftDown, self.bRightDown]:
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
      self.cbDrawRegion.wEvent_CheckBox   do (event: wEvent): self.onCheckBoxDrawRegion(event)
      self.cbDrawRegion.wEvent_MouseEnter do (event: wEvent): self.onCheckboxMouseEnterLeave(event)
      self.cbDrawRegion.wEvent_MouseLeave do (event: wEvent): self.onCheckboxMouseEnterLeave(event)
      self.cbMonitor.wEvent_Checkbox      do (event: wEvent): self.onMonitorCheckBox(event)

    block: # Initial values
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

    block: # Update arrow buttons down below after the radio buttons are clicked, so they have the right icon
      self.cbDrawRegion.setBitmap(iconBitmap("drag", iconSz))
      self.updateCompactButton(self.bLeft,      Normal)
      self.updateCompactButton(self.bRight,     Normal)
      self.updateCompactButton(self.bUp,        Normal)
      self.updateCompactButton(self.bDown,      Normal)
      self.updateCompactButton(self.bLeftUp,    Normal)
      self.updateCompactButton(self.bRightUp,   Normal)
      self.updateCompactButton(self.bLeftDown,  Normal)
      self.updateCompactButton(self.bRightDown, Normal)


wClass(wPlacementFrame of wFrame):
  proc onClose(self: wPlacementFrame, event: wEvent) =
    # You can logic or check to event.veto() to 
    # stop the frame from closing and cascading
    # onDestroys down the tree
    # event.skip will override the veto(), but that's dumb
    # so don't use it
    echo "PlacementFrame onClose; hiding"
    self.hide()
    event.veto()

  proc onDestroy(self: wPlacementFrame) =
    # event.veto doesn't do anything here
    # Do cleanup and announcements here
    when defined(debug):
      echo "PlacementFrame onDestroy; sending idPFDestroying"
    sendToListeners(idPFDestroying, self.handle.WPARAM, 0)

  proc init*(self: wPlacementFrame, owner: wWindow) =
    wFrame(self).init(owner, title = "Placement")
    self.backgroundColor = gFrameBackgroundColor
    self.mPanel = PlacementPanel(self)
    self.mPanel.layout()
    self.clientSize = self.mPanel.requiredSize(ignore=[self.mPanel.bDone.wControl,
                                                       self.mPanel.bUndo.wControl])
    # Respond to generic events
    self.wEvent_Close do (event: wEvent): self.onClose(event)
    self.wEvent_Destroy do (): self.onDestroy()


when isMainModule:
  var plf: wPlacementFrame
  try:
    wSetSystemDPIAware()
    registerListener(Qty, proc(q: int) = echo "Listener says Qty: ", q)
    registerListener(RandAll, proc() = echo "Listener says RandAll")
    registerListener(RandPos, proc() = echo "Listener says RandPos")
    registerListener(Test, proc() = echo "Listener says Test")
    registerListener(RegionX, proc(x: float) = echo "Listener says RegionX: ", x)
    registerListener(RegionY, proc(y: float) = echo "Listener says RegionY: ", y)
    registerListener(RegionW, proc(w: float) = echo "Listener says RegionW: ", w)
    registerListener(RegionH, proc(h: float) = echo "Listener says RegionH: ", h)
    registerListener(CompactReq, proc(req: CompactRequest) =
      echo "Listener says CompactRequest: ", req)
    registerListener(Undo, proc() = echo "Listener says Undo")

    when defined(dumpLayout):
      PlacementFrame(nil)
    else:
      let
        app = App()
        appFrame = Frame(nil, title="Fake Application Frame")
        goButton = Button(appFrame, label="Press me")
      plf = PlacementFrame(appFrame)
      goButton.wEvent_Button do(): plf.show()
      appFrame.show()
      app.mainLoop()
  except Exception as e:
    echo e.msg
    echo e.getStackTrace()
