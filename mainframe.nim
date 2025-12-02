import std/[os, strformat, strutils, sugar, tables]

import wNim
from winim import LOWORD, HIWORD, DWORD, WORD, WPARAM, LPARAM
from winim/inc/winbase import MulDiv
import winim/inc/windef
import appinit, routing
import viewport, utils
import mainpanel, aboutframe, gridctrlframe, grid
export mainpanel


type
  wMainFrame* = ref object of wFrame
    mGridCtrlFrameShowing: bool
    mMainPanel*: wMainPanel
    #mMenuBar: wMenuBar
    #mStatusBar: wStatusBar
    mBandToolBars: seq[wToolBar]
    #mReBar: wReBar
  MenuCmdID = enum
    idTool1 = wIdUser, idCmdGridShow, idCmdGridSetting, 
              idCmdNew, idCmdOpen, idCmdSave, idCmdClose,
              idCmdExit, idCmdHelp, idCmdInfo,idCmdAbout

const
  singleFrames = false
  pth = r"icons/24x24_free_application_icons_icons_pack_120732/bmp/24x24/"
  res = [staticRead(pth & r"New document.bmp"),
         staticRead(pth & r"Folder.bmp"),
         staticRead(pth & r"Save.bmp"),
         staticRead(pth & r"Close.bmp"),
         staticRead(pth & r"Exit.bmp"),
         staticRead(pth & r"Info.bmp"),
         staticRead(pth & r"Help book.bmp"),
         staticRead(pth & r"Add.bmp"),
         staticRead(r"icons/grid.bmp"),
         staticRead(r"icons/gridgears.bmp")]
let
  small = MulDiv(16, wAppGetDpi(), 96)
  big = MulDiv(32, wAppGetDpi(), 96)
  imgLstSm = ImageList(small, small)
  imgLstBg = ImageList(big, big)

for r in res:
  imgLstSm.add(Image(r).scale(small, small))
  imgLstBg.add(Image(r).scale(big, big))

let
  bmpNewSm    = imgLstSm.getBitmap(0)
  bmpOpenSm   = imgLstSm.getBitmap(1)
  bmpSaveSm   = imgLstSm.getBitmap(2)
  bmpCloseSm  = imgLstSm.getBitmap(3)
  bmpExitSm   = imgLstSm.getBitmap(4)
  bmpInfoSm   = imgLstSm.getBitmap(5)
  bmpHelpSm   = imgLstSm.getBitmap(6)
  bmpAddSm    = imgLstSm.getBitmap(7)
  bmpGridSm   = imgLstSm.getBitmap(8)
  bmpGearsSm  = imgLstSm.getBitmap(9)

  bmpNewBg    = imgLstBg.getBitmap(0)
  bmpOpenBg   = imgLstBg.getBitmap(1)
  bmpSaveBg   = imgLstBg.getBitmap(2)
  bmpCloseBg  = imgLstBg.getBitmap(3)
  bmpExitBg   = imgLstBg.getBitmap(4)
  bmpInfoBg   = imgLstBg.getBitmap(5)
  bmpHelpBg   = imgLstBg.getBitmap(6)
  bmpAddBg    = imgLstBg.getBitmap(7)
  bmpGridBg   = imgLstBg.getBitmap(8)
  bmpGearsBg  = imgLstBg.getBitmap(9)



wClass(wMainFrame of wFrame):
  proc onResize(self: wMainFrame, event: wEvent) =
    self.mMainPanel.size = self.clientSize
    self.mStatusBar.setStatusText($self.clientSize, index=1)
  proc onUserMouseNotify(self: wMainFrame, event: wEvent) =
    # event can contain either client or screen coordinates
    # so ignore wparam and lparam.  Just grab  mouse pos directly
    let mousePxPos = screenToClient(self.mMainPanel.mBlockPanel, wGetMousePosition())
    let mouseWPos: WPoint = mousePxPos.toWorld(self.mMainPanel.mBlockPanel.mViewport)
    when WType is SomeFloat:
      let mwpx = &"{mouseWPos.x:0.4f}"
      let mwpy = &"{mouseWPos.y:0.4f}"
    elif WType is SomeInteger:
      let mwpx = &"{mouseWPos.x}"
      let mwpy = &"{mouseWPos.y}"
    let txt = &"Pixel: {mousePxPos}; World: ({mwpx}, {mwpy})"
    self.mStatusBar.setStatusText(txt, index=2)
  proc onUserSliderNotify(self: wMainFrame, event: wEvent) =
    let tmpStr = &"temperature: {event.mLparam}"
    self.mStatusBar.setStatusText(tmpStr, index=0)
  proc onToolEvent(self: wMainFrame, event: wEvent) =
    case event.id
    of idCmdNew: discard
    of idCmdOpen:
      let f = FileDialog(self, defaultDir=getCurrentDir(), style=wFdMultiple)
      f.show()
    of idCmdSave: discard
    of idCmdClose: self.destroy()
    of idCmdExit: self.destroy()
    of idCmdHelp: discard
    of idCmdInfo:
      echo self.mMainPanel.mBlockPanel.mGrid[]
      echo self.mMainPanel.mBlockPanel.mViewport[]
      echo self.mMainPanel.mBlockPanel.mGrid.mZctrl[]
    of idCmdAbout:
      let f = AboutFrame(self)
      f.show()
    of idCmdGridShow:
      # We know this comes from the second toolbar in the rebar hence [1]
      let state = self.mBandToolbars[1].toolState(idCmdGridShow)
      sendToListeners(idMsgGridVisible, self.mHwnd.WPARAM, state.LPARAM)
    of idCmdGridSetting:
      if not singleFrames or not self.mGridCtrlFrameShowing:
        let gr = self.mMainPanel.mBlockPanel.mGrid
        GridControlFrame(self, gr).show()
        if singleFrames:
          self.mGridCtrlFrameShowing = true
    else:
      discard


  proc onMsgGridSize(self: wMainFrame, event: wEvent) =
    # Received value is what the user wants at this zoom level
    # Need to calc value to set grid.majorSpace so minDelta(Major) == val
    let gr = self.mMainPanel.mBlockPanel.mGrid
    let newSz = gr.calcReferenceSpace(derefAs[WType](event))
    if event.mMsg == idMsgGridRequestX:
      gr.refYSpace = newsz
      gr.refXSpace = newsz
      echo "refXSpace:   ", gr.refXSpace
      echo "minDelta:    ", gr.minDelta(Major)
      # Send message to update display to both X and Y
      sendToListeners(idMsgGridSizeX, event.wParam, event.lParam)
      sendToListeners(idMsgGridSizeY, event.wParam, event.lParam)
    elif event.mMsg == idMsgGridRequestY:
      gr.refYSpace = newsz
      # Send message to update display to only Y
      sendToListeners(idMsgGridSizeY, event.wParam, event.lParam)
    self.mMainPanel.mBlockPanel.refresh(false)
    sendToListeners(idMsgGridDivisionsReset, 0, 0)
  
  proc onMsgGridDivisionsSelect(self: wMainFrame, event: wEvent) =
    # Change divisions based on given index and force zoom
    var gr = self.mMainPanel.mBlockPanel.mGrid
    var vp = self.mMainPanel.mBlockPanel.mViewport
    let oldz = vp.rawZoom
    gr.divisions = gr.allowedDivisions()[event.mLparam]
    vp.rawZoom = oldz
    self.mMainPanel.mBlockPanel.refresh(false)

  proc onMsgGridDivisionsValue(self: wMainFrame, event: wEvent) =
    # Change divisions based on given value and force zoom
    # Presumably the value is not in allowed divisions because
    # if it were we would be in onMsgGridDivisionsSelect
    # We're here because user typed in a value, which may or
    # may not be in allowed divisions, ie able to divide grid 
    # size exactly.  We do however assume it's been validated
    # otherwise, which means it should be in DivRange
    var gr = self.mMainPanel.mBlockPanel.mGrid
    var vp = self.mMainPanel.mBlockPanel.mViewport
    let oldz = vp.rawZoom
    gr.divisions = event.mLparam
    vp.rawZoom = oldz
    self.mMainPanel.mBlockPanel.refresh(false)

  proc onMsgGridDensity(self: wMainFrame, event: wEvent) =
    let mag = event.lParam.float / 100.0
    self.mMainPanel.mBlockPanel.mGrid.mZctrl.density = mag
    self.mMainPanel.mBlockPanel.mViewport.doZoom(0)
    self.mMainPanel.mBlockPanel.refresh(false)
  #--
  proc onMsgGridSnap(self: wMainFrame, event: wEvent) =
    self.mMainPanel.mBlockPanel.mGrid.mSnap = event.lParam.bool
  proc onMsgGridDynamic(self: wMainFrame, event: wEvent) =
    self.mMainPanel.mBlockPanel.mGrid.mZctrl.dynamic = event.lParam.bool
    self.mMainPanel.mBlockPanel.mViewport.resetZoom()
    self.mMainPanel.mBlockPanel.refresh(false)
  proc onMsgGridBaseSync(self: wMainFrame, event: wEvent) =
    var gr = self.mMainPanel.mBlockPanel.mGrid
    var zc = self.mMainPanel.mBlockPanel.mGrid.mZctrl
    var vp = self.mMainPanel.mBlockPanel.mViewport
    zc.baseSync = event.lParam.bool
    # gr.divisions below is ignored when basySync false
    let oldz = vp.rawZoom
    zc.updateBase(gr.divisions)
    vp.rawZoom = oldz
    self.mMainPanel.mBlockPanel.refresh(false)
    
  #--
  proc onMsgGridVisible(self: wMainFrame, event: wEvent) =
    let state = event.mLparam.bool
    self.mMainPanel.mBlockPanel.mGrid.mVisible = state
    self.mBandToolbars[1].toggleTool(idCmdGridShow, state)
    self.mMainPanel.mBlockPanel.refresh(false)
  proc onMsgGridDots(self: wMainFrame, event: wEvent) =
    let val = event.lParam.bool
    if val: self.mMainPanel.mBlockPanel.mGrid.mDotsOrLines = Dots
    else:   self.mMainPanel.mBlockPanel.mGrid.mDotsOrLines = Lines
    self.mMainPanel.mBlockPanel.refresh(false)
  proc onMsgGridLines(self: wMainFrame, event: wEvent) =
    let val = event.lParam.bool
    if val: self.mMainPanel.mBlockPanel.mGrid.mDotsOrLines = Lines
    else:   self.mMainPanel.mBlockPanel.mGrid.mDotsOrLines = Dots
    self.mMainPanel.mBlockPanel.refresh(false)
  #--
  proc onMsgGridCtrlFrameClosing(self: wMainFrame, event: wEvent) =
    self.mGridCtrlFrameShowing = false

  proc setupMenuBar(self: wMainFrame): wMenuBar =
    # Main menu at top of frame
    var menu1 = Menu()
    var menu2 = Menu()
    result = MenuBar(self)
    menu1.append(idCmdNew, "New", bitmap=bmpNewSm)
    menu1.append(idCmdOpen, "Open", bitmap=bmpOpenSm)
    menu1.append(idCmdSave, "Save", bitmap=bmpSaveSm)
    menu1.append(idCmdClose, "Close", bitmap=bmpCloseSm)
    menu1.appendSeparator()
    menu1.append(idCmdExit, "Exit", bitmap=bmpExitSm)
    menu2.append(idCmdAbout, "About", bitmap=bmpInfoSm)
    menu2.append(idCmdHelp, "Help", bitmap=bmpHelpSm)
    result.append(menu1, "File")
    result.append(menu2, "Help")

  proc setupReBar(self: wMainFrame): wReBar =
    # Set up three things in the rebar
    result = ReBar(self)

    # 1. Basic file new/open toolbar
    let tb1 = ToolBar(result)
    tb1.addTool(idCmdNew, "New", bmpNewBg)
    tb1.addTool(idCmdOpen, "Open", bmpOpenBg)
    tb1.addTool(idCmdSave, "Save", bmpSaveBg)
    self.mBandToolBars.add(tb1)
    
    # 2. Grid controls    
    let tb2 = ToolBar(result)
    tb2.addChecktool(idCmdGridShow, "Grid Show", bmpGridBg)
    # Read from init file
    tb2.toggleTool(idCmdGridShow, gGridSpecsJ["visible"].getBool)
    tb2.addtool(idCmdGridSetting, "Grid settings", bmpGearsBg)

    let ddcb = ComboBox(tb2, 0, "My dropdown")
    ddcb.size = (self.dpiScale(150), ddcb.size.height)
    ddcb.append("Option 1")
    ddcb.append("Option 2")
    ddcb.position = (self.dpiScale(150), self.dpiScale(10))


    self.mBandToolBars.add(tb2)
    
    # 3. Close
    let tb3 = ToolBar(result)
    tb3.addTool(idCmdInfo, "Info", bmpInfoBg)
    tb3.addTool(idCmdClose, "Close", bmpCloseBg)
    self.mBandToolBars.add(tb3)

    # Put toolbars things in rebar
    let bid1 = result.addBand(tb1)
    let bid2 = result.addBand(tb2)
    let _    = result.addBand()
    let bid3 = result.addBand(tb3)
    result.setBandWidth(bid3, 32)
    result.setBandWidth(bid2, 200)
    result.setBandWidth(bid1, 64)
    result.disableDrag()

  proc show*(self: wMainFrame) =
    # Need to call forcredraw a couple times after show
    # So we're just hiding it in an overloaded show()
    wFrame.show(self)
    self.mMainPanel.mBlockPanel.forceRedraw()
    self.mMainPanel.mBlockPanel.forceRedraw()
  proc init*(self: wMainFrame, size: wSize) = 
    wFrame(self).init(title="Blocks Frame", size=size)
    when defined(debug):
      echo "Main frame is ", $self.mHwnd
    
    # Create controls
    self.mMenuBar   = setupMenuBar(self)
    self.mReBar     = setupRebar(self)
    self.mMainPanel = MainPanel(self)
    self.mStatusBar = StatusBar(self)

    # Do stuff
    self.mStatusBar.setStatusWidths([-1, -1, -1])
    
    # A couple of cheats because I'm not sure how to do these when the mBlockPanel is 
    # finally rendered at the proper size
    let sldrVal = self.mMainPanel.mSldr.value
    let tmpStr = &"temperature: {sldrVal}"
    self.mStatusBar.setStatusText(tmpStr, index=0)
    self.mMainPanel.randomizeRectsAll()

    # Connect Events
    self.wEvent_Size          do (event: wEvent): self.onResize(event)
    self.idMsgMouseMove       do (event: wEvent): self.onUserMouseNotify(event)
    self.idMsgSlider          do (event: wEvent): self.onUserSliderNotify(event)

    # Participate in observables/listeners
    # Respond to buttons & send msg
    self.wEvent_Tool do (event: wEvent): self.onToolEvent(event)
    
    # Respond to incoming messages
    self.registerListener(idMsgGridRequestX,        (w:wWindow, e:wEvent)=>onMsgGridSize(w.wMainFrame, e))
    self.registerListener(idMsgGridRequestY,        (w:wWindow, e:wEvent)=>onMsgGridSize(w.wMainFrame, e))
    self.registerListener(idMsgGridDivisionsSelect, (w:wWindow, e:wEvent)=>onMsgGridDivisionsSelect(w.wMainFrame, e))
    self.registerListener(idMsgGridDivisionsValue,  (w:wWindow, e:wEvent)=>onMsgGridDivisionsValue(w.wMainFrame, e))
    self.registerListener(idMsgGridDensity,         (w:wWindow, e:wEvent)=>onMsgGridDensity(w.wMainFrame, e))
    #---
    self.registerListener(idMsgGridSnap,     (w:wWindow, e:wEvent)=>onMsgGridSnap(w.wMainFrame, e))
    self.registerListener(idMsgGridDynamic,  (w:wWindow, e:wEvent)=>onMsgGridDynamic(w.wMainFrame, e))
    self.registerListener(idMsgGridBaseSync, (w:wWindow, e:wEvent)=>onMsgGridBaseSync(w.wMainFrame, e))
    #--
    self.registerListener(idMsgGridVisible, (w:wWindow, e:wEvent)=>onMsgGridVisible(w.wMainFrame, e))
    self.registerListener(idMsgGridDots,    (w:wWindow, e:wEvent)=>onMsgGridDots(w.wMainFrame, e))
    self.registerListener(idMsgGridLines,   (w:wWindow, e:wEvent)=>onMsgGridLines(w.wMainFrame, e))
    
    self.registerListener(idMsgGridCtrlFrameClosing, (w:wWindow, e:wEvent)=>onMsgGridCtrlFrameClosing(w.wMainFrame, e))
  
when isMainModule:
    # Main data and window
    let
      app = App()
      init_size = (800, 800)
      frame = MainFrame(init_size)
    
    # Go App!
    frame.center()
    frame.show()
    app.mainLoop()

