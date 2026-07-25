import wNim/[wApp, wMacros, wFrame, wPanel, wEvent, wButton]

type wButtonPanel = ref object of wPanel
    mB1: wButton
    mB2: wButton

wClass(wButtonPanel of wPanel):
  proc layout(self: wButtonPanel) =
      self.autolayout  """
      V:|-[self.mB1][self.mB2]
      """

  proc init(self: wButtonPanel, parent: wWindow) =
    wPanel(self).init(parent)
    self.mB1 = Button(self, label="Randomize")
    self.mB2 = Button(self, label="Compact X←")
    self.layout()
    self.wEvent_Size do():
      self.layout()

let app = App(wSystemDpiAware)
let frame = Frame(title="Button Frame", size=(600,400))
let bp = ButtonPanel(frame)
discard bp

frame.center()
frame.show()
app.mainLoop()