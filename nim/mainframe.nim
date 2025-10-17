import std/[strformat]
import wNim
from winim import LOWORD, HIWORD, DWORD, WORD, WPARAM, LPARAM
import mainpanel, userMessages
import viewport
export mainpanel


type
  wMainFrame* = ref object of wFrame
    mMainPanel*: wMainPanel
    #mMenuBar: wMenuBar
    mToolBar: wToolBar
  MenuID = enum
    idTool1 = wIdUser, idGridShow, idGridSetting, idNew, idOpen, idClose, idExit, idHelp, idAbout


# const resource1 = staticRead(r"images/1.png")
# const resource2 = staticRead(r"images/2.png")
# const resource3 = staticRead(r"images/3.png")
# const resource4 = staticRead(r"images/4.png")
# const resource5 = staticRead(r"images/5.png")

# let img1 = Image(resource1).scale(36, 36)
# let img2 = Image(resource2).scale(36, 36)
# let img3 = Image(resource3).scale(36, 36)
# let img4 = Image(resource4).scale(36, 36)
# let img5 = Image(resource5).scale(36, 36)


const
  pth = r"icons/24x24_free_application_icons_icons_pack_120732/bmp/24x24/"
  res = [staticRead(pth & r"New document.bmp"),
         staticRead(pth & r"Folder.bmp"),
         staticRead(pth & r"Close.bmp"),
         staticRead(pth & r"Exit.bmp"),
         staticRead(pth & r"Info.bmp"),
         staticRead(pth & r"Help book.bmp"),
         staticRead(r"icons/grid.bmp"),
         staticRead(r"icons/gridgears.bmp")]
var gBMPs64: seq[wBitmap]
var gBMPs32: seq[wBitmap]
for i in res:
  gBMPs64.add(Bitmap(Image(i).scale(64, 64)))
  gBMPs32.add(Bitmap(Image(i).scale(32, 32)))


wClass(wMainFrame of wFrame):
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
    result.addSeparator()
    result.addCheckTool(idGridShow, "", gBMPs64[6], "Toggle grid", "Toggle grid")
    result.addSeparator()
    result.addTool(idGridSetting, "", gBMPs64[7], "Grid settings", "Grid settings")
    result.addSeparator()

  proc setupMenuBar(self: wMainFrame): wMenuBar =
    var menu1 = Menu()
    var menu2 = Menu()
    result = MenuBar(self)
    menu1.append(idNew, "New", bitmap=gBMPs32[0])
    menu1.append(idOpen, "Open", bitmap=gBMPs32[1])
    menu1.append(idClose, "Close", bitmap=gBMPs32[2])
    menu1.appendSeparator()
    menu1.append(idExit, "Exit", bitmap=gBMPs32[3])
    menu2.append(idAbout, "About", bitmap=gBMPs32[4])
    menu2.append(idHelp, "Help", bitmap=gBMPs32[5])
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
    
    # A couple of cheats because I'm not sure how to do these when the mBlockPanel is 
    # finally rendered at the proper size
    let sldrVal = self.mMainPanel.mSldr.value
    let tmpStr = &"temperature: {sldrVal}"
    self.mStatusBar.setStatusText(tmpStr, index=0)
    self.mStatusBar.setStatusText($newBlockSz, index=1)
    self.mMainPanel.randomizeRectsAll()

    # # Connect Events
    self.wEvent_Size     do (event: wEvent): self.onResize(event)
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

