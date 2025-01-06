import wNim/[wApp, wMacros, wFrame, wPanel, wEvent, wButton, wPaintDC, wBrush, autolayout]
import std/[random, strformat]

wClass(wBlockPanel of wPanel):
  # Declare out-of-order procs
  proc onPaint(self: wBlockPanel, event: wEvent)
  # proc onKeyMouse(self: wBlockPanel, event: wEvent)
  # proc randrgb(self: wBlockPanel): int

  proc init(self: wBlockPanel, parent: wWindow) = 
    echo "1"
    wPanel(self).init(style=wBorderSimple)
    echo "2"
    #self.backgroundColor = parent.backgroundColor
    #self.setDoubleBuffered(true)
    self.wEvent_Paint do (event: wEvent): self.onPaint(event) 
    # self.wEvent_Size do (): self.refresh(false)
    # self.wEvent_ScrollWin do (): self.refresh(false)
    # self.wEvent_MouseMove do (event: wEvent): self.onKeyMouse(event)
    # self.wEvent_KeyDown do (event: wEvent): self.onKeyMouse(event)
    # self.wEvent_KeyUp do (event: wEvent): self.onKeyMouse(event)
    echo "3"

  proc onPaint(self: wBlockPanel, event: wEvent) = 
    echo "paintstart"
    var dc: wPaintDC = PaintDC(event.window)
    echo "paintdone"
    # var sz = dc.mCanvas.size
    # for i in 1..1000:
    #   var brush = Brush(wColor(self.randrgb()))
    #   setBrush(dc, brush)
    #   var x = rand(sz.width)
    #   var y = rand(sz.height)
    #   var w = rand(10..50)
    #   var h = rand(10..50)
    #   var rect = (x,y,w,h)
    #   drawRectangle(dc, rect)

  # proc randrgb(self: wBlockPanel): int = 
  #   var r: int = rand(255).shl(16)
  #   var g: int = rand(255).shl(8)
  #   var b: int = rand(255).shl(0)
  #   return r or g or b

  # proc onKeyMouse(self: wBlockPanel, event: wEvent) =
  #   echo "hi"

wClass(wMainPanel of wPanel):
  proc init(self: wMainPanel, parent: wWindow) =
    wPanel(self).init(parent)
    var button1 = Button(self, label="Randomize")
    var button2 = Button(self, label="Stack left")
    var blockPanel = BlockPanel(self)

    proc layout(self: wMainPanel) =
      self.autolayout  """
        V:|-[col1:[button1]-[button2]~]|
        H:|-[col1]-[blockPanel]-|
        """
    self.layout()
    self.wEvent_Size do():
      self.layout()




when isMainModule:
  let app = App(wSystemDpiAware)
  let frame = Frame(title="Blocks Frame", size=(600,400))
  let mainPanel = MainPanel(frame)


  frame.center()
  frame.show()

  randomize()
  
  app.mainLoop()