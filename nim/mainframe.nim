import std/[strformat, tables]
import wNim
from winim import LOWORD, HIWORD, DWORD, WORD, WPARAM, LPARAM
import mainpanel, userMessages
import aboutframe
import viewport
export mainpanel


type
  wMainFrame* = ref object of wFrame
    mMainPanel*: wMainPanel
    #mMenuBar: wMenuBar
    #mStatusBar: wStatusBar
    mToolBar: wToolBar
  MenuID = enum
    idTool1 = wIdUser, idGridShow, idGridSetting, idNew, idOpen, idSave, idClose, idExit, idHelp, idAbout



const
  pth = r"icons/24x24_free_application_icons_icons_pack_120732/bmp/24x24/"
  res = [staticRead(pth & r"New document.bmp"),
         staticRead(pth & r"Folder.bmp"),
         staticRead(pth & r"Save.bmp"),
         staticRead(pth & r"Close.bmp"),
         staticRead(pth & r"Exit.bmp"),
         staticRead(pth & r"Info.bmp"),
         staticRead(pth & r"Help book.bmp"),
         staticRead(r"icons/grid.bmp"),
         staticRead(r"icons/gridgears.bmp")]
let
  bmpNewSm    = Bitmap(Image(res[0]).scale(16, 16))
  bmpOpenSm   = Bitmap(Image(res[1]).scale(16, 16))
  bmpSaveSm   = Bitmap(Image(res[2]).scale(16, 16))
  bmpCloseSm  = Bitmap(Image(res[3]).scale(16, 16))
  bmpExitSm   = Bitmap(Image(res[4]).scale(16, 16))
  bmpInfoSm   = Bitmap(Image(res[5]).scale(16, 16))
  bmpHelpSm   = Bitmap(Image(res[6]).scale(16, 16))
  bmpGridSm   = Bitmap(Image(res[7]).scale(16, 16))
  bmpGearsSm  = Bitmap(Image(res[8]).scale(16, 16))

  bmpNewBg    = Bitmap(Image(res[0]).scale(32, 32))
  bmpOpenBg   = Bitmap(Image(res[1]).scale(32, 32))
  bmpSaveBg   = Bitmap(Image(res[2]).scale(32, 32))
  bmpCloseBg  = Bitmap(Image(res[3]).scale(32, 32))
  bmpExitBg   = Bitmap(Image(res[4]).scale(32, 32))
  bmpInfoBg   = Bitmap(Image(res[5]).scale(32, 32))
  bmpHelpBg   = Bitmap(Image(res[6]).scale(32, 32))
  bmpGridBg   = Bitmap(Image(res[7]).scale(32, 32))
  bmpGearsBg  = Bitmap(Image(res[8]).scale(32, 32))



wClass(wMainFrame of wFrame):
  proc showHelpWindow(self: wMainFrame)

  proc onResize(self: wMainFrame, event: wEvent) =
    self.mMainPanel.size = 
      (event.size.width, 
       event.size.height - 
       self.mStatusBar.size.height -
       self.mToolBar.size.height)

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
      echo self.mToolBar.toolState(idGridShow)
      self.mMainPanel.mBlockPanel.mGrid.visible = self.mToolBar.toolState(idGridShow)
      self.mMainPanel.mBlockPanel.refresh(false)
    of idGridSetting: stdout.write("grid setting")
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

  proc setupToolBar(self: wMainFrame): wToolBar =
    # img1 = Image(resource1).scale(sz, sz)
    # img2 = Image(resource2).scale(sz, sz)
    result = ToolBar(self,style=wTbFlat)
    result.addTool(idNew, "", bmpNewBg, "New", "New")
    result.addTool(idOpen, "", bmpOpenBg, "Open", "Open")
    result.addTool(idSave, "", bmpSaveBg, "Save", "Save")
    result.addSeparator()
    result.addCheckTool(idGridShow, "", bmpGridBg, "Toggle grid", "Toggle grid")
    result.addTool(idGridSetting, "", bmpGearsBg, "Grid settings", "Grid settings")
    result.addSeparator()
    result.addTool(idClose, "", bmpCloseBg, "Close", "Close")

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


  proc init*(self: wMainFrame, newBlockSz: wSize) = 
    wFrame(self).init(title="Blocks Frame")
    
    # Create controls
    self.mMenuBar     = setupMenuBar(self)
    self.mToolBar     = setupToolBar(self)
    self.mMainPanel   = MainPanel(self)
    self.mStatusBar   = StatusBar(self)

    let
      otherWidth  = self.size.width  - self.mMainPanel.mBlockPanel.clientSize.width
      otherHeight = self.size.height - self.mMainPanel.mBlockPanel.clientSize.height
      newWidth    = newBlockSz.width  + otherWidth
      newHeight   = newBlockSz.height + otherHeight + 23

    # Do stuff
    self.size = (newWidth, newHeight)
    self.mStatusBar.setStatusWidths([-1, -1, 600])
    self.mToolBar.backgroundColor = self.mMainPanel.backgroundColor * 19 / 20
    self.mToolBar.toggleTool(idGridShow)
    
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

