import wNim/[wApp, wMacros, wFrame, wPanel, wEvent, wButton, wPaintDC, wBrush,
             wStatusBar, wMenuBar,]
import std/[random, strformat, bitops]
import winim


const
  USER_MOUSE_MOVE = WM_APP + 1
  USER_SIZE       = WM_APP + 2

proc EventParam(event: wEvent): tuple = 
  let lo_word:int = event.mLparam.bitand(0x0000_ffff)
  let hi_word:int = event.mLparam.bitand(0xffff_0000).shr(16)
  result = (lo_word, hi_word)



proc `$`(event: wEvent): string =
  let (lo_word, hi_word) = EventParam(event)
  echo "mWindow.HWND:", event.mWindow.mHwnd
  #echo "mWindow.parent.HWND:", event.mWindow.mParent.mHwnd
  echo "mOrigin:", event.mOrigin #: HWND
  echo "mMsg:", event.mMsg #: UINT
  echo "mId:", event.mId #: wCommandID
  echo "mWparam:", event.mWparam #: WPARAM
  echo "mLparam:", event.mLparam #: LPARAM
  echo "mUserData:", event.mUserData #: int
  echo "mSkip:", event.mSkip #: bool
  echo "mPropagationLevel:", event.mPropagationLevel #: int
  echo "mResult:", event.mResult #: LRESULT
  #echo "mKeyStatus:", event.mKeyStatus #: array[256, int8] # use int8 so that we can test if it < 0
  echo "mMousePos:", event.mMousePos #: wPoint
  echo "mClientPos:", event.mClientPos #: wPoint
  echo "getMousePos:", event.getMousePos()
  echo "lo_word:", lo_word
  echo "hi_word:", hi_word


wClass(wBlockPanel of wPanel):
  # Declare out-of-order procs
  proc onPaint(self: wBlockPanel, event: wEvent)
  proc randrgb(self: wBlockPanel): int

  proc init(self: wBlockPanel, parent: wWindow) = 
    wPanel(self).init(parent)#, style=wBorderSimple)
    self.backgroundColor = parent.backgroundColor
    self.doubleBuffered = true
    self.setDoubleBuffered(true)
    self.wEvent_Paint do (event: wEvent): self.onPaint(event) 
    self.wEvent_MouseMove do (event: wEvent):
      broadcastTopLevelMessage(wBaseApp, USER_MOUSE_MOVE, event.mWparam, event.mLparam)
    self.wEvent_Size do (event: wEvent):
      broadcastTopLevelMessage(wBaseApp, USER_SIZE, event.mWparam, event.mLparam)

  proc onPaint(self: wBlockPanel, event: wEvent) = 
    var dc: wPaintDC = PaintDC(event.window)
    var sz = dc.mCanvas.size
    for i in 1..100:
      var brush = Brush(wColor(self.randrgb()))
      setBrush(dc, brush)
      var x = rand(sz.width)
      var y = rand(sz.height)
      var w = rand(10..50)
      var h = rand(10..50)
      var rect = (x,y,w,h)
      drawRectangle(dc, rect)

  proc randrgb(self: wBlockPanel): int = 
    var r: int = rand(255).shl(16)
    var g: int = rand(255).shl(8)
    var b: int = rand(255).shl(0)
    return r or g or b


wClass(wMainPanel of wPanel):
  proc init(self: wMainPanel, parent: wWindow) =
    wPanel(self).init(parent, style=wBorderSimple)
    let
      b1  = Button(self, label = "Randomize"         )
      b2  = Button(self, label = "Compact X←"        )
      b3  = Button(self, label = "Compact X→"        )
      b4  = Button(self, label = "Compact Y↑"        )
      b5  = Button(self, label = "Compact Y↓"        )
      b6  = Button(self, label = "Compact X← then Y↑")
      b7  = Button(self, label = "Compact X← then Y↓")
      b8  = Button(self, label = "Compact X→ then Y↑")
      b9  = Button(self, label = "Compact X→ then Y↓")
      b10 = Button(self, label = "Compact Y↑ then X←")
      b11 = Button(self, label = "Compact Y↑ then X→")
      b12 = Button(self, label = "Compact Y↓ then X←")
      b13 = Button(self, label = "Compact Y↓ then X→")
      b14 = Button(self, label = "Save"              )
      b15 = Button(self, label = "Load"              )
      blockPanel = BlockPanel(self)

    proc layout_internal() =
      let 
        bmarg = 8
        lmarg = 0
        rmarg = 0
        bw = 130
        bh = 30
        butts = [b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15]
        new_x = bw + 2*bmarg + lmarg
        new_y = 0
        new_width  = self.clientSize.width - bw - 2*bmarg - lmarg - rmarg
        new_height = self.clientSize.height # - 2*marg
      blockPanel.position = (new_x, new_y)
      blockPanel.size = (new_width, new_height)
      for i, butt in butts:
        butt.position = (bmarg, bmarg + i * bh)
        butt.size     = (bw, bh)
    layout_internal()
    self.wEvent_Size do(event: wEvent):
      layout_internal()



when isMainModule:
  let 
    app = App()
    frame = Frame(title="Blocks Frame", size=(800,600))
    mainPanel = MainPanel(frame)
    menuBar = MenuBar(frame)
    menuFile = Menu(menuBar, "&File")
    statusBar = StatusBar(frame)
  menuFile.append(1, "Open")
  statusBar.setStatusWidths([-2, -1, 100])
  
  frame.wEvent_Size do (event: wEvent):
    mainPanel.size = (event.size.width, 
                      event.size.height - statusBar.size.height)
  
  frame.USER_SIZE do (event: wEvent):
    statusBar.setStatusText($event.EventParam.wSize, 1)

  frame.USER_MOUSE_MOVE do (event: wEvent):
      statusBar.setStatusText($event.mMousePos, 2)
  
  frame.center()
  frame.show()
  randomize()
  app.mainLoop()