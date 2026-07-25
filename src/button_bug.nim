import wNim/[wApp, wFrame, wPanel, wEvent, wButton]

let app = App(wSystemDpiAware)
let frame = Frame(title="Button Frame", size=(600,400))
let panel = Panel(frame)

var b1 = Button(panel, label="Randomize")
var b2 = Button(panel, label="Compact X←")
var b3 = Button(panel, label="Compact X→")
var b4 = Button(panel, label="Compact Y↑")
var b5 = Button(panel, label="Compact Y↓")
var b6 = Button(panel, label="Compact X← then Y↑")
var b7 = Button(panel, label="Compact X← then Y↓")

proc layout(panel: wPanel) =
  panel.autolayout  """
    V:|-[b1][b2][b3][b4][b5][b6][b7]
    H:[b1..7(120)]
    """
panel.wEvent_Size do():
  panel.layout()
panel.layout()

frame.center()
frame.show()
app.mainLoop()