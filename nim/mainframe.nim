import std/[strformat, tables]

import wNim
from winim import LOWORD, HIWORD, DWORD, WORD, WPARAM, LPARAM
from winim/inc/winbase import MulDiv
import appinit, userMessages
import viewport
import mainpanel, aboutframe, gridctrlframe
export mainpanel


type
  wMainFrame* = ref object of wFrame
    mMainPanel*: wMainPanel
    #mMenuBar: wMenuBar
    #mStatusBar: wStatusBar
    mBandToolBars: seq[wToolBar]
    #mReBar: wReBar
  MenuID = enum
    idTool1 = wIdUser, idGridShow, idGridSetting, idNew, idOpen, idSave, idClose, idExit, idHelp, idAbout
  BandID = enum
    idFileBand, idGridBand, idCloseBand


const
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

  proc onUserSizeNotify(self: wMainFrame, event: wEvent) =
    let sz = (LOWORD(event.lParam).int, HIWORD(event.lParam).int)
    self.mStatusBar.setStatusText($sz, index=1)

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
    let evtStr = $MenuID(event.id)
    echo evtStr
    case event.id
    of idNew: echo "new"
    of idOpen: echo "open"
    of idSave: echo "save"
    of idClose: self.delete()
    of idExit: self.delete()
    of idHelp: echo "help"
    of idAbout:
      let f = AboutFrame(self)
      f.show()
    of idGridShow:
      # We know this comes from the second toolbar in the rebar
      let state = self.mBandToolbars[1].toolState(idGridShow)
      self.mMainPanel.mBlockPanel.mGrid.visible = state
      self.mMainPanel.mBlockPanel.refresh(false)
    of idGridSetting:
      let
        gr = self.mMainPanel.mBlockPanel.mGrid
        zc = self.mMainPanel.mBlockPanel.mViewport.zctrl
      let f = GridControlFrame(self, gr, zc)
      f.show()
    else: stdout.write("default")


  
  proc show*(self: wMainFrame) =
    # Need to call forcredraw a couple times after show
    # So we're just hiding it in an overloaded show()
    wFrame.show(self)
    self.mMainPanel.mBlockPanel.forceRedraw()
    self.mMainPanel.mBlockPanel.forceRedraw()

  proc setupMenuBar(self: wMainFrame): wMenuBar =
    var menu1 = Menu()
    var menu2 = Menu()
    result = MenuBar(self)
    menu1.append(idNew, "New", bitmap=bmpNewSm)
    menu1.append(idOpen, "Open", bitmap=bmpOpenSm)
    menu1.append(idSave, "Save", bitmap=bmpSaveSm)
    menu1.append(idClose, "Close", bitmap=bmpCloseSm)
    menu1.appendSeparator()
    menu1.append(idExit, "Exit", bitmap=bmpExitSm)
    menu2.append(idAbout, "About", bitmap=bmpInfoSm)
    menu2.append(idHelp, "Help", bitmap=bmpHelpSm)
    result.append(menu1, "File")
    result.append(menu2, "Help")

  proc setupReBar(self: wMainFrame): wReBar =
    # Set up three things in the rebar

    result = ReBar(self)

    # 1. Basic file new/open toolbar
    let tb1 = ToolBar(result)
    tb1.addTool(idNew, "New", bmpNewBg)
    tb1.addTool(idOpen, "Open", bmpOpenBg)
    tb1.addTool(idSave, "Open", bmpSaveBg)
    self.mBandToolBars.add(tb1)
    
    # 2. Grid controls    
    let tb2 = ToolBar(result)
    tb2.addChecktool(idGridShow, "Grid Show", bmpGridBg)
    # Read from init file
    tb2.toggleTool(idGridShow, gGridSpecs["visible"].getBool)
    tb2.addtool(idGridSetting, "Grid settings", bmpGearsBg)
    self.mBandToolBars.add(tb2)
    
    # 3. Close
    let tb3 = ToolBar(result)
    tb3.addTool(idClose, "Close", bmpCloseBg)
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


  proc init*(self: wMainFrame, size: wSize) = 
    wFrame(self).init(title="Blocks Frame", size=size)
    
    # Create controls
    self.mMenuBar     = setupMenuBar(self)
    self.mReBar       = setupRebar(self)
    self.mMainPanel   = MainPanel(self)
    self.mStatusBar   = StatusBar(self)

    # Do stuff
    self.mStatusBar.setStatusWidths([-1, -1, -1])
    
    # A couple of cheats because I'm not sure how to do these when the mBlockPanel is 
    # finally rendered at the proper size
    let sldrVal = self.mMainPanel.mSldr.value
    let tmpStr = &"temperature: {sldrVal}"
    self.mStatusBar.setStatusText(tmpStr, index=0)
    self.mMainPanel.randomizeRectsAll()

    # Connect Events
    self.wEvent_Size     do (event: wEvent): self.onResize(event)
    self.wEvent_Tool     do (event: wEvent): self.onToolEvent(event)
    self.USER_SIZE       do (event: wEvent): self.onUserSizeNotify(event)
    self.USER_MOUSE_MOVE do (event: wEvent): self.onUserMouseNotify(event)
    self.USER_SLIDER     do (event: wEvent): self.onUserSliderNotify(event)
  
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

