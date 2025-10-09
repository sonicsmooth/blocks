import std/[strformat, strutils, sugar]
import wNim
from winim import LOWORD, HIWORD, DWORD, WORD, WPARAM, LPARAM
import mainpanel, userMessages, utils
import viewport
from db import QTY
export mainpanel


type
  wMainFrame* = ref object of wFrame
    mMainPanel*: wMainPanel
    #mMenuBar:   wMenuBar # already defined by wNim
    mMenuFile:  wMenu
    #mStatusBar: wStatusBar # already defined by wNim


wClass(wMainFrame of wFrame):
  proc onResize(self: wMainFrame, event: wEvent) =
    self.mMainPanel.size = 
      (event.size.width, 
       event.size.height - self.mStatusBar.size.height)

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

  proc init*(self: wMainFrame, newBlockSz: wSize) = 
    wFrame(self).init(title="Blocks Frame")
    
    # Create controls
    self.mMainPanel   = MainPanel(self, QTY)
    self.mMenuBar     = MenuBar(self)
    self.mMenuFile    = Menu(self.mMenuBar, "&File")
    self.mStatusBar   = StatusBar(self)

    let
      otherWidth  = self.size.width  - self.mMainPanel.mBlockPanel.clientSize.width
      otherHeight = self.size.height - self.mMainPanel.mBlockPanel.clientSize.height
      newWidth    = newBlockSz.width  + otherWidth
      newHeight   = newBlockSz.height + otherHeight + 23

    # Do stuff
    self.size = (newWidth, newHeight)
    self.mMenuFile.append(1, "Open")
    self.mStatusBar.setStatusWidths([-1, -1, 600])
    
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
  

