import std/[os, strformat, strutils, sugar, tables]
import appopts
import wNim
from winim import LOWORD, HIWORD, DWORD, WORD, WPARAM, LPARAM
from winim/inc/winbase import MulDiv
import winim/inc/windef
import appinit, routing
import viewport, utils
import mainpanel, aboutframe, gridctrlframe, grid
export mainpanel

# TODO: mainframe should have ref to editor, doc

type
  wMainFrame* = ref object of wFrame
    gridCtrlFrameShowing: bool
    mainPanel*: wMainPanel
    #mMenuBar: wMenuBar
    #mStatusBar: wStatusBar
    bandToolBars: seq[wToolBar]
    #reBar: wReBar
  MenuCmdID = enum
    idTool1 = wIdUser, idCmdGridShow, idCmdGridSetting, 
              idCmdNew, idCmdOpen, idCmdSave, idCmdClose,
              idCmdOptions,
              idCmdExit, idCmdHelp, idCmdInfo,idCmdAbout

const
  singleFrames = false
  pth = r"icons/24x24_free_application_icons_icons_pack_120732/bmp/24x24/"
  res = [staticRead(pth & r"New document.bmp"),
         staticRead(pth & r"Folder.bmp"),
         staticRead(pth & r"Save.bmp"),
         staticRead(pth & r"Close.bmp"),
         staticRead(pth & r"Application.bmp"),
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
  bmpNewSm     = imgLstSm.getBitmap(0)
  bmpOpenSm    = imgLstSm.getBitmap(1)
  bmpSaveSm    = imgLstSm.getBitmap(2)
  bmpCloseSm   = imgLstSm.getBitmap(3)
  bmpOptionsSm = imgLstSm.getBitmap(4)
  bmpExitSm    = imgLstSm.getBitmap(5)
  bmpInfoSm    = imgLstSm.getBitmap(6)
  bmpHelpSm    = imgLstSm.getBitmap(7)
  bmpAddSm     = imgLstSm.getBitmap(8)
  bmpGridSm    = imgLstSm.getBitmap(9)
  bmpGearsSm   = imgLstSm.getBitmap(10)

  bmpNewBg     = imgLstBg.getBitmap(0)
  bmpOpenBg    = imgLstBg.getBitmap(1)
  bmpSaveBg    = imgLstBg.getBitmap(2)
  bmpCloseBg   = imgLstBg.getBitmap(3)
  bmpOptionsBg = imgLstBg.getBitmap(4)
  bmpExitBg    = imgLstBg.getBitmap(5)
  bmpInfoBg    = imgLstBg.getBitmap(6)
  bmpHelpBg    = imgLstBg.getBitmap(7)
  bmpAddBg     = imgLstBg.getBitmap(8)
  bmpGridBg    = imgLstBg.getBitmap(9)
  bmpGearsBg   = imgLstBg.getBitmap(10)



wClass(wMainFrame of wFrame):
  proc onResize(self: wMainFrame, event: wEvent) =
    self.mainPanel.size = self.clientSize
    self.statusBar.setStatusText($self.clientSize, index=1)
  proc onUserMouseNotify(self: wMainFrame, event: wEvent) =
    # event can contain either client or screen coordinates
    # so ignore wparam and lparam.  Just grab  mouse pos directly
    let mousePxPos = screenToClient(self.mainPanel.blockPanel, wGetMousePosition())
    let mouseWPos: WPoint = mousePxPos.toWorld(self.mainPanel.blockPanel.editor.viewport)
    when WType is SomeFloat:
      let mwpx = &"{mouseWPos.x:0.4f}"
      let mwpy = &"{mouseWPos.y:0.4f}"
    elif WType is SomeInteger:
      let mwpx = &"{mouseWPos.x}"
      let mwpy = &"{mouseWPos.y}"
    let txt = &"Pixel: {mousePxPos}; World: ({mwpx}, {mwpy})"
    self.statusBar.setStatusText(txt, index=2)
  proc onUserSliderNotify(self: wMainFrame, event: wEvent) =
    let tmpStr = &"temperature: {event.mLparam}"
    self.statusBar.setStatusText(tmpStr, index=0)
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
      echo self.mainPanel.blockPanel.editor.doc.grid[]
      echo self.mainPanel.blockPanel.editor.viewport[]
      echo self.mainPanel.blockPanel.editor.doc.grid.mZctrl[]
    of idCmdAbout:
      let f = AboutFrame(self)
      f.show()
    of idCmdGridShow:
      # We know this comes from the second toolbar in the rebar hence [1]
      let state = self.bandToolbars[1].toolState(idCmdGridShow)
      sendToListeners(idMsgGridVisible, self.mHwnd.WPARAM, state.LPARAM)
    of idCmdGridSetting:
      if not singleFrames or not self.gridCtrlFrameShowing:
        let gr = self.mainPanel.blockPanel.editor.doc.grid
        GridControlFrame(self, gr).show()
        if singleFrames:
          self.gridCtrlFrameShowing = true
    else:
      discard
  proc onMsgGridSize(self: wMainFrame, event: wEvent) =
    # Received value is what the user wants at this zoom level
    # Need to calc value to set grid.majorSpace so minDelta(Major) == val
    let gr = self.mainPanel.blockPanel.editor.doc.grid
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
    self.mainPanel.blockPanel.refresh(false)
    sendToListeners(idMsgGridDivisionsReset, 0, 0)
  proc onMsgGridDivisionsSelect(self: wMainFrame, event: wEvent) =
    # Change divisions based on given index and force zoom
    var gr = self.mainPanel.blockPanel.editor.doc.grid
    var vp = self.mainPanel.blockPanel.editor.viewport
    let oldz = vp.rawZoom
    gr.divisions = gr.allowedDivisions()[event.mLparam]
    vp.rawZoom = oldz
    self.mainPanel.blockPanel.refresh(false)
  proc onMsgGridDivisionsValue(self: wMainFrame, event: wEvent) =
    # Change divisions based on given value and force zoom
    # Presumably the value is not in allowed divisions because
    # if it were we would be in onMsgGridDivisionsSelect
    # We're here because user typed in a value, which may or
    # may not be in allowed divisions, ie able to divide grid 
    # size exactly.  We do however assume it's been validated
    # otherwise, which means it should be in DivRange
    var gr = self.mainPanel.blockPanel.editor.doc.grid
    var vp = self.mainPanel.blockPanel.editor.viewport
    let oldz = vp.rawZoom
    gr.divisions = event.mLparam
    vp.rawZoom = oldz
    self.mainPanel.blockPanel.refresh(false)
  proc onMsgGridDensity(self: wMainFrame, event: wEvent) =
    let mag = event.lParam.float / 100.0
    self.mainPanel.blockPanel.editor.doc.grid.mZctrl.density = mag
    self.mainPanel.blockPanel.editor.viewport.doZoom(0)
    self.mainPanel.blockPanel.refresh(false)
  #--
  proc onMsgGridSnap(self: wMainFrame, event: wEvent) =
    self.mainPanel.blockPanel.editor.doc.grid.mSnap = event.lParam.bool
  proc onMsgGridDynamic(self: wMainFrame, event: wEvent) =
    self.mainPanel.blockPanel.editor.doc.grid.mZctrl.dynamic = event.lParam.bool
    self.mainPanel.blockPanel.editor.viewport.resetZoom()
    self.mainPanel.blockPanel.refresh(false)
  proc onMsgGridBaseSync(self: wMainFrame, event: wEvent) =
    var gr = self.mainPanel.blockPanel.editor.doc.grid
    var zc = self.mainPanel.blockPanel.editor.doc.grid.mZctrl
    var vp = self.mainPanel.blockPanel.editor.viewport
    zc.baseSync = event.lParam.bool
    # gr.divisions below is ignored when basySync false
    let oldz = vp.rawZoom
    zc.updateBase(gr.divisions)
    vp.rawZoom = oldz
    self.mainPanel.blockPanel.refresh(false)
  #--
  proc onMsgGridVisible(self: wMainFrame, event: wEvent) =
    let state = event.mLparam.bool
    self.mainPanel.blockPanel.editor.doc.grid.mVisible = state
    self.bandToolbars[1].toggleTool(idCmdGridShow, state)
    self.mainPanel.blockPanel.refresh(false)
  proc onMsgGridDots(self: wMainFrame, event: wEvent) =
    let val = event.lParam.bool
    if val: self.mainPanel.blockPanel.editor.doc.grid.mDotsOrLines = Dots
    else:   self.mainPanel.blockPanel.editor.doc.grid.mDotsOrLines = Lines
    self.mainPanel.blockPanel.refresh(false)
  proc onMsgGridLines(self: wMainFrame, event: wEvent) =
    let val = event.lParam.bool
    if val: self.mainPanel.blockPanel.editor.doc.grid.mDotsOrLines = Lines
    else:   self.mainPanel.blockPanel.editor.doc.grid.mDotsOrLines = Dots
    self.mainPanel.blockPanel.refresh(false)
  #--
  proc onMsgGridCtrlFrameClosing(self: wMainFrame, event: wEvent) =
    self.gridCtrlFrameShowing = false

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
    menu1.append(idCmdOptions, "Options", bitmap=bmpOptionsSm)
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
    self.bandToolBars.add(tb1)
    
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


    self.bandToolBars.add(tb2)
    
    # 3. Close
    let tb3 = ToolBar(result)
    tb3.addTool(idCmdInfo, "Info", bmpInfoBg)
    tb3.addTool(idCmdClose, "Close", bmpCloseBg)
    self.bandToolBars.add(tb3)

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
    # self.mainPanel.blockPanel.forceRedraw()
    # self.mainPanel.blockPanel.forceRedraw()
  proc init*(self: wMainFrame, size: wSize) = 
    wFrame(self).init(title="Blocks Frame", size=size)
    when defined(debug):
      echo "Main frame is ", $self.mHwnd
    
    # Create controls
    self.mMenuBar   = setupMenuBar(self)
    self.mReBar      = setupRebar(self)
    self.mStatusBar = StatusBar(self)
    self.mainPanel  = MainPanel(self)

    # TODO: move stuff around so it's easy to comment out main panel, etc
    # TODO: eg setupMainPanel() with the appropriate argumets

    # Do stuff
    self.statusBar.setStatusWidths([-1, -1, -1])
    
    # A couple of cheats because I'm not sure how to do these when the blockPanel is 
    # finally rendered at the proper size
    let sldrVal = self.mainPanel.slider.value
    let tmpStr = &"temperature: {sldrVal}"
    self.statusBar.setStatusText(tmpStr, index=0)
    # self.mainPanel.randomizeRectsAll()

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
  try:
    gAppOpts = parseAppOptions()
    if gAppOpts.appHelp:
      showAppHelp(gAppOpts)
      system.quit()
    let
      app = App()
      init_size = (800, 800)
      frame = MainFrame(init_size)
    
    # Go App!
    frame.center()
    frame.show()
    app.mainLoop()
  except Exception as e:
      echo "Exception!"
      echo e.msg
      echo getStackTrace(e)
    

    

