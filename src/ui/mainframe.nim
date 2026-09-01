import std/[os,
            strformat,
            strutils,
            sugar,
            tables
            ]
import wNim
#from winim import LOWORD, HIWORD, DWORD, WORD, WPARAM, LPARAM
from winim/inc/winbase import MulDiv
import winim/inc/windef

import aboutframe
import appopts
import document
import editor
import grid
import gridctrlframe
import icons
import jsoninit
import mainpanel
import placementframe
import reporting
import routing
import usermessages
import wnimutils
import viewport
export mainpanel

type
  wMainFrame* = ref object of wFrame
    editor*: Editor
    doc*: Document
    gridCtrlFrameShowing: bool
    placementFrameShowing: bool
    mainPanel*: wMainPanel
    bandToolBars: seq[wToolBar]
    invalidate*: proc()
  MenuCmdID = enum
    idTool1 = wIdUser, idCmdGridShow, idCmdGridSetting, 
              idCmdNew, idCmdOpen, idCmdSave, idCmdClose,
              idCmdPrefs, idCmdDropDown,
              idCmdExit, idCmdHelp, idCmdInfo,idCmdAbout,
              idCmdPlace

const
  small: wSize = (24, 24)
  big: wSize = (48, 48)

var
  gQuietReady: bool

wClass(wMainFrame of wFrame):
  proc isReady*(self: wMainFrame): bool =
    if gQuietReady:
      if self.editor.isNil: return false
      if self.mainPanel.isNil: return false
      if self.statusBar.isNil: return false
      if not self.editor.isReady(): return false
      if not self.mainPanel.isReady(): return false
      true
    else:
      if self.editor.isNil: return reportNil("wMainFrame.editor")
      if self.mainPanel.isNil: return reportNil("wMainFrame.mainPanel")
      if self.statusBar.isNil: return reportNil("wMainFrame.statusBar")
      if not self.editor.isReady(): return reportNotReady("wMainFrame.editor")
      if not self.mainPanel.isReady(): return reportNotReady("wMainFrame.mainPanel")
      true

  proc onResize(self: wMainFrame, event: wEvent) =
    if self.isReady:
      self.statusBar.setStatusText($self.mainPanel.blockPanel.clientSize, index=1)
    event.skip()
  
  proc refreshCanvas(self: wMainFrame) =
    when defined(debug):
      echo "mainframe refresh"
    if self.mainPanel != nil:
      self.mainPanel.layout()
    if self.isReady:
      self.mainPanel.blockPanel.refresh(false)

  proc setupMenuBar(self: wMainFrame): wMenuBar =
    # Main menu at top of frame
    var menu1 = Menu()
    var menu2 = Menu()
    var menu3 = Menu()
    result = MenuBar(self)
    result.append(menu1, "File")
    result.append(menu2, "Tools")
    result.append(menu3, "Help")

    menu1.append(idCmdNew, "New", bitmap=iconBitmap("new_document", small))
    menu1.append(idCmdOpen, "Open",  bitmap=iconBitmap("file_open", small))
    menu1.append(idCmdSave, "Save",  bitmap=iconBitmap("save", small))
    menu1.append(idCmdClose, "Close", bitmap=iconBitmap("close", small))
    menu1.appendSeparator()
    menu1.append(idCmdPrefs, "Preferences", bitmap=iconBitmap("preferences", small))
    menu1.appendSeparator()
    menu1.append(idCmdExit, "Exit", bitmap=iconBitmap("exit", small))
    menu2.append(idCmdPlace, "Place", bitmap=iconBitmap("place", small))
    menu3.append(idCmdAbout, "About", bitmap=iconBitmap("info", small))
    menu3.append(idCmdHelp, "Help", bitmap=iconBitmap("help", small))


  proc setupReBar(self: wMainFrame): wReBar =
    # Set up three things in the rebar
    result = ReBar(self)

    # 1. Basic file new/open toolbar
    let tb1 = ToolBar(result)
    tb1.addTool(idCmdNew, "New", iconBitmap("new_document", big))
    tb1.addTool(idCmdOpen, "Open", iconBitmap("file_open", big))
    tb1.addTool(idCmdSave, "Save", iconBitmap("save", big))
    self.bandToolBars.add(tb1) # self.bandToolBars[0]
    
    # 2. Grid controls    
    let tb2 = ToolBar(result)
    tb2.addChecktool(idCmdGridShow, "Grid Show", iconBitmap("gridonoff", big))
    # Read from init file
    tb2.toggleTool(idCmdGridShow, gGridSpecsJ["visible"].getBool)
    tb2.addtool(idCmdGridSetting, "Grid settings", iconBitmap("gridsettings", big))
    tb2.addTool(idCmdPlace, "Place", iconBitmap("place", big))

    let ddcb = ComboBox(tb2, idCmdDropDown, "Render Method")
    ddcb.size = (self.dpiScale(150), ddcb.size.height)
    ddcb.append("SDL Direct")
    ddcb.append("SDL Texture")
    ddcb.append("Pixie Texture")
    ddcb.select(gAppOpts.renderMethod.int)
    ddcb.position = (self.dpiScale(250), self.dpiScale(10))
    self.bandToolBars.add(tb2) # self.bandToolBars[1]

    # 3. Close
    let tb3 = ToolBar(result)
    tb3.addTool(idCmdInfo, "Info", iconBitmap("info", big))
    tb3.addTool(idCmdClose, "Close", iconBitmap("close", big))
    self.bandToolBars.add(tb3) # self.bandToolBars[2]

    # Put toolbars things in rebar
    let bid1 = result.addBand(tb1)
    let bid2 = result.addBand(tb2)
    let _    = result.addBand()
    let bid3 = result.addBand(tb3)
    result.setBandWidth(bid3, 32)
    result.setBandWidth(bid2, 200)
    result.setBandWidth(bid1, 64)
    result.disableDrag()

  proc setupStatusBar(self: wMainFrame): wStatusBar =
    result = StatusBar(self)
    result.setStatusWidths([-1, -1, -1])

  proc onToolEvent(self: wMainFrame, event: wEvent) =
    case event.id
    of idCmdNew: discard
    of idCmdOpen:
      var files = FileDialog(nil, defaultDir=getCurrentDir(), style=wFdMultiple).display()
      echo files
    of idCmdSave: discard
    of idCmdDropDown:
      let v = event.window.wComboBox.value.replace(" ")
      gAppOpts.renderMethod = parseEnum[RenderMethod](v)
      self.invalidate()
    of idCmdClose: self.destroy()
    of idCmdExit: self.destroy()
    of idCmdHelp: discard
    of idCmdInfo:
      if self.isReady():
        echo self.mainPanel.blockPanel.editor
        # TODO: show channels, listeners, font cache, etc.
    of idCmdAbout:
      let f = AboutFrame(self)
      f.show()
    of idCmdGridShow:
      # We know this comes from the second toolbar in the rebar hence [1]
      let state = self.bandToolbars[1].toolState(idCmdGridShow)
      sendToListeners(idGCFVisible, self.mHwnd.WPARAM, state.LPARAM)
    of idCmdGridSetting:
      if self.gridCtrlFrameShowing: return
      if self.mainPanel.isNil: return
      let gr = self.mainPanel.blockPanel.editor.doc.grid
      GridControlFrame(self, gr).show()
      self.gridCtrlFrameShowing = true
    of idCmdPlace:
      if self.placementFrameShowing: return
      if self.mainPanel.isNil: return
      PlacementFrame(self).show()
      self.placementFrameShowing = true

    else:
      discard

  proc onUserMouseNotify(self: wMainFrame, event: wEvent) =
    # TODO: fix this so the event carries the proper information
    # event can contain either client or screen coordinates
    # so ignore wparam and lparam.  Just grab  mouse pos directly
    if self.isReady():
      let mouseWPos: Wpoint = self.mainPanel.blockPanel.mouseWorldPosition()
      let mousePxPos: PxPoint = self.mainPanel.blockPanel.mouseClientPosition()
      when WType is SomeFloat:
        let mwpx = &"{mouseWPos.x:0.4f}"
        let mwpy = &"{mouseWPos.y:0.4f}"
      elif WType is SomeInteger:
        let mwpx = &"{mouseWPos.x}"
        let mwpy = &"{mouseWPos.y}"
      let txt = &"Pixel: {mousePxPos}; World: ({mwpx}, {mwpy})"
      self.statusBar.setStatusText(txt, index=2)

  proc onUserSliderNotify(self: wMainFrame, event: wEvent) =
    if self.statusBar != nil:
      let tmpStr = &"temperature: {event.mLparam}"
      self.statusBar.setStatusText(tmpStr, index=0)

  proc onGCFSize(self: wMainFrame, event: wEvent) =
    # Received value is what the user wants at this zoom level
    # Need to calc value to set grid.majorSpace so minDelta(Major) == val
    if self.isReady():
      let gr = self.editor.doc.grid
      let newSz = gr.calcReferenceSpace(derefAs[WType](event))
      if event.mMsg == idGCFRequestX:
        gr.refYSpace = newsz
        gr.refXSpace = newsz
        echo "refXSpace:   ", gr.refXSpace
        echo "minDelta:    ", gr.minDelta(Major)
        # Send message to update display to both X and Y
        sendToListeners(idGCFSizeX, event.wParam, event.lParam)
        sendToListeners(idGCFSizeY, event.wParam, event.lParam)
      elif event.mMsg == idGCFRequestY:
        gr.refYSpace = newsz
        # Send message to update display to only Y
        sendToListeners(idGCFSizeY, event.wParam, event.lParam)
      self.refreshCanvas()
      sendToListeners(idGCFDivisionsReset, 0, 0)

  proc onGCFDivisionsSelect(self: wMainFrame, event: wEvent) =
    # Change divisions based on given index and force zoom
    if self.isReady():
      var gr = self.editor.doc.grid
      var vp = self.editor.viewport
      let oldz = vp.rawZoom
      gr.divisions = gr.allowedDivisions()[event.mLparam]
      vp.rawZoom = oldz
      self.refreshCanvas()

  proc onGCFDivisionsValue(self: wMainFrame, event: wEvent) =
    # Change divisions based on given value and force zoom
    # Presumably the value is not in allowed divisions because
    # if it were we would be in onidGCFDivisionsSelect
    # We're here because user typed in a value, which may or
    # may not be in allowed divisions, ie able to divide grid 
    # size exactly.  We do however assume it's been validated
    # otherwise, which means it should be in DivRange
    if self.isReady():
      var gr = self.editor.doc.grid
      var vp = self.editor.viewport
      let oldz = vp.rawZoom
      gr.divisions = event.mLparam
      vp.rawZoom = oldz
      self.refreshCanvas()

  proc onGCFDensity(self: wMainFrame, event: wEvent) =
    if self.isReady():
      let mag = event.lParam.float / 100.0
      self.editor.doc.grid.mZctrl.density = mag
      self.editor.viewport.doZoom(0)
      self.refreshCanvas()
  #--

  proc onGCFSnap(self: wMainFrame, event: wEvent) =
    if self.isReady():
      self.editor.doc.grid.mSnap = event.lParam.bool

  proc onGCFDynamic(self: wMainFrame, event: wEvent) =
    if self.isReady():
      self.editor.doc.grid.mZctrl.dynamic = event.lParam.bool
      self.editor.viewport.resetZoom()
      self.refreshCanvas()

  proc onGCFBaseSync(self: wMainFrame, event: wEvent) =
    if self.isReady():
      var gr = self.editor.doc.grid
      var zc = self.editor.doc.grid.mZctrl
      var vp = self.editor.viewport
      zc.baseSync = event.lParam.bool
      # gr.divisions below is ignored when baseSync false
      let oldz = vp.rawZoom
      zc.updateBase(gr.divisions)
      vp.rawZoom = oldz
      self.refreshCanvas()
  #--

  proc onGCFVisible(self: wMainFrame, event: wEvent) =
    discard
    # if self.isReady():
    #   let state = event.mLparam.bool
    #   self.editor.doc.grid.mVisible = state
    #   self.bandToolbars[1].toggleTool(idCmdGridShow, state)
    #   self.refreshCanvas()

  proc onGCFDots(self: wMainFrame, event: wEvent) =
    if self.isReady():
      let val = event.lParam.bool
      if val: self.editor.doc.grid.mDotsOrLines = Dots
      else:   self.editor.doc.grid.mDotsOrLines = Lines
      self.refreshCanvas()

  proc onGCFLines(self: wMainFrame, event: wEvent) =
    if self.isReady():
      let val = event.lParam.bool
      if val: self.editor.doc.grid.mDotsOrLines = Lines
      else:   self.editor.doc.grid.mDotsOrLines = Dots
      self.refreshCanvas()
  #--

  proc onGCFCtrlFrameClosing(self: wMainFrame, event: wEvent) =
    self.gridCtrlFrameShowing = false
  proc onMsgPlacementFrameClosing(self: wMainFrame, event: wEvent) =
    self.placementFrameShowing = false

  proc show*(self: wMainFrame) =
    # Need to call forcredraw a couple times after show
    # So we're just hiding it in an overloaded show()
    when defined(debug):
      echo "mainframe show"
    wFrame.show(self)
    self.refreshCanvas()
  
  proc onTimer(self: wMainFrame, event: wEvent) = 
    if event.timerId == 1:
      self.stopTimer(event.timerId)
      #if self.statusBar != nil:
      if self.isReady:
        # Same as onresize
        self.statusBar.setStatusText($self.mainPanel.blockPanel.clientSize, index=1)
      event.skip()

  proc init*(self: wMainFrame, size: wSize, barebones: bool) = 
    when defined(debug):
      echo "mainframe init"
      echo "Main frame hwnd is ", $self.mHwnd
    wFrame(self).init(title="Blocks Frame", size=size)
    
    # Create controls -- these are declared in wNim already
    self.mMenuBar   = self.setupMenuBar()
    self.mReBar     = self.setupRebar()
    self.mStatusBar = self.setupStatusBar()
    
    var accel = self.AcceleratorTable()
    accel.add('i', idCmdInfo)

    # Connect internal Events
    self.wEvent_Size     do (event: wEvent): self.onResize(event)
    self.wEvent_Tool     do (event: wEvent): self.onToolEvent(event)
    self.wEvent_ComboBox do (event: wEvent): self.onToolEvent(event)
    self.wEvent_Timer    do (event: wEvent): self.onTimer(event)

    # Respond to buttons & send msg
    self.idMsgMouseMove       do (event: wEvent): self.onUserMouseNotify(event)
    self.idMsgSlider          do (event: wEvent): self.onUserSliderNotify(event)

    # Startup
    self.startTimer(0.0,   id=1) # one-shot to start
    
    # # Respond to incoming messages
    self.registerListener(idGCFRequestX,        (w:wWindow, e:wEvent)=>onidGCFSize(w.wMainFrame, e))
    self.registerListener(idGCFRequestY,        (w:wWindow, e:wEvent)=>onidGCFSize(w.wMainFrame, e))
    self.registerListener(idGCFDivisionsSelect, (w:wWindow, e:wEvent)=>onidGCFDivisionsSelect(w.wMainFrame, e))
    self.registerListener(idGCFDivisionsValue,  (w:wWindow, e:wEvent)=>onidGCFDivisionsValue(w.wMainFrame, e))
    self.registerListener(idGCFDensity,         (w:wWindow, e:wEvent)=>onidGCFDensity(w.wMainFrame, e))
    #---
    self.registerListener(idGCFSnap,     (w:wWindow, e:wEvent)=>onidGCFSnap(w.wMainFrame, e))
    self.registerListener(idGCFDynamic,  (w:wWindow, e:wEvent)=>onidGCFDynamic(w.wMainFrame, e))
    self.registerListener(idGCFBaseSync, (w:wWindow, e:wEvent)=>onidGCFBaseSync(w.wMainFrame, e))
    #--
    self.registerListener(idGCFVisible, (w:wWindow, e:wEvent)=>onidGCFVisible(w.wMainFrame, e))
    self.registerListener(idGCFDots,    (w:wWindow, e:wEvent)=>onidGCFDots(w.wMainFrame, e))
    self.registerListener(idGCFLines,   (w:wWindow, e:wEvent)=>onidGCFLines(w.wMainFrame, e))
    #--
    self.registerListener(idGCFCtrlFrameClosing, (w:wWindow, e:wEvent)=>onidGCFCtrlFrameClosing(w.wMainFrame, e))
    self.registerListener(idPlcFrameClosing, (w:wWindow, e:wEvent)=>onMsgPlacementFrameClosing(w.wMainFrame, e))
    
    if not barebones:
      self.mainPanel = MainPanel(self)
    when defined(debug):
      echo "Main frame done initting"

  
when isMainModule:
  gQuietReady = true

  # Main data and window
  try:
    gAppOpts = parseAppOptions()
    wSetSystemDpiAware()
    let app = wNim.App()
    let init_size = (1200, 800)
    let frame = MainFrame(init_size, barebones=true)
    
    # Go App!
    frame.center()
    frame.show()
    app.mainLoop()
  
  except Exception as e:
      echo "Exception!"
      echo e.msg
      echo getStackTrace(e)
    

    

