import std/[strformat, tables]
import wNim
from winim import LOWORD, HIWORD, DWORD, WORD, WPARAM, LPARAM
import mainpanel, userMessages
import aboutframe, gridctrlpanel
import viewport
export mainpanel


type
  wMainFrame* = ref object of wFrame
    mMainPanel*: wMainPanel
    #mMenuBar: wMenuBar
    #mStatusBar: wStatusBar
    #mToolBar: wToolBar
    #mReBar: wReBar
  MenuID = enum
    idTool1 = wIdUser, idGridShow, idGridSetting, idNew, idOpen, idSave, idClose, idExit, idHelp, idAbout
  BandID = enum
    idFileBand, idGridBand, idCloseBand


const
  small = 16
  big = 32
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
  proc showHelpWindow(self: wMainFrame)

  proc onResize(self: wMainFrame, event: wEvent) =
    self.mMainPanel.size = self.clientSize
    # self.mMainPanel.size = 
    #   (event.size.width, 
    #    event.size.height - 
    #    self.mRebar.size.height -
    #    self.mStatusBar.size.height)

  proc onUserSizeNotify(self: wMainFrame, event: wEvent) =
    let sz = (LOWORD(event.lParam).WORD, 
              HIWORD(event.lParam).WORD)
    self.mStatusBar.setStatusText($sz, index=1)

  proc onUserMouseNotify(self: wMainFrame, event: wEvent) =
    # event can contain either client or screen coordinates
    # so ignore wparam and lparam.  Just grab  mouse pos directly
    let mousePxPos = screenToClient(self.mMainPanel.mBlockPanel, wGetMousePosition())
    let mouseWPos: WPoint = mousePxPos.toWorld(self.mMainPanel.mBlockPanel.mViewPort)
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
    case event.id
    of idNew: stdout.write("new")
    of idOpen: stdout.write("open")
    of idSave: stdout.write("save")
    of idClose: self.delete()
    of idExit: self.delete()
    of idHelp: stdout.write("help")
    of idAbout:
      self.showHelpWindow()
    of idGridShow:
      discard
      # echo self.mToolBar.toolState(idGridShow)
      # let tb = self.mRebar.
      # self.mMainPanel.mBlockPanel.mGrid.visible = self.mToolBar.toolState(idGridShow)
      # self.mMainPanel.mBlockPanel.refresh(false)
    of idGridSetting:
      stdout.write("grid setting")
      let f = Frame(self, "Grid Settings", size=(485, 285))
      let p = GridControlPanel(f)
      f.show()
    else: stdout.write("default")
    echo evtStr

  proc showHelpWindow(self: wMainFrame) =
    let f = AboutFrame(self)
    f.show()

  
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
    # Set up three things in the rebar:
      # 1. Basic file new/open toolbar
      # 2. Grid controls panel
      # 3. Close toolbar

    # 1. Basic file new/open toolbar
    let rebar = ReBar(self)
    let tb1 = ToolBar(rebar)
    rebar.setImageList(imgLstBg)
    tb1.addTool(idNew, "", bmpNewBg, "New", "New")
    tb1.addTool(idOpen, "", bmpOpenBg, "Open", "Open")
    let bid1 = rebar.addBand(tb1)
    
    # 2. Grid controls    
    let tb2 = ToolBar(rebar)
    rebar.setImageList(imgLstBg)
    tb2.addtool(idGridShow, "Grid Show", bmpGridBg, "Show Grid")
    tb2.addtool(idGridSetting, "Grid settings", bmpGearsBg, "Grid Settings")
    let bid2 = rebar.addBand(tb2)
    
    # 3. Close
    let tb3 = ToolBar(rebar)
    tb3.addTool(idClose, "", bmpCloseBg, "Close", "Close")
    rebar.addBand()
    let bid3 = rebar.addBand(tb3)
    rebar.setBandWidth(bid3, 32)
    rebar.setBandWidth(bid2, 200)
    rebar.setBandWidth(bid1, 64)

    return rebar


  proc init*(self: wMainFrame, newBlockSz: wSize) = 
    wFrame(self).init(title="Blocks Frame")
    
    # Create controls
    self.mMenuBar     = setupMenuBar(self)
    self.mReBar       = setupRebar(self)
    self.mMainPanel   = MainPanel(self)
    self.mStatusBar   = StatusBar(self)

    let
      otherWidth  = self.size.width  - self.mMainPanel.mBlockPanel.clientSize.width
      otherHeight = self.size.height - self.mMainPanel.mBlockPanel.clientSize.height
      newWidth    = newBlockSz.width  + otherWidth
      newHeight   = newBlockSz.height + otherHeight + 23

    # Do stuff
    self.size = (newWidth, newHeight)
    self.mStatusBar.setStatusWidths([-1, -1, -1])
    #self.mToolBar.toggleTool(idGridShow)
    #self.mToolBar.backgroundColor = self.mMainPanel.backgroundColor * 19 / 20
    
    # A couple of cheats because I'm not sure how to do these when the mBlockPanel is 
    # finally rendered at the proper size
    let sldrVal = self.mMainPanel.mSldr.value
    let tmpStr = &"temperature: {sldrVal}"
    self.mStatusBar.setStatusText(tmpStr, index=0)
    self.mStatusBar.setStatusText($newBlockSz, index=1)
    self.mMainPanel.randomizeRectsAll()

    # # Connect Events
    self.wEvent_Size     do (event: wEvent): self.onResize(event)
    self.wEvent_tool     do (event: wEvent): self.onToolEvent(event)
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

