import wNim/[wApp]
import std/[random, tables, strformat]
import frames

const
  WRANGE: tuple[min:Natural, max:Natural] = (min:25, max:50)
  HRANGE: tuple[min:Natural, max:Natural] = (min:25, max:50)
  QTY = 10

type Rect = object
  id: string
  pos: wPoint
  size: wSize
  pencolor: wColor
  brushcolor: wColor
  selected: bool
type RectTable = Table[string, Rect]


proc `$`(r: Rect): string =
  result =
    "{id: \"" & r.id & "\", " &
    "pos: " & $r.pos & ", " &
    "size: " & $r.size & ", " &
    "pencolor: " & &"0x{r.pencolor:0x}" & ", " &
    "brushcolor: " & &"0x{r.brushcolor:0x}" & ", " &
    "selected: " & $r.selected & "}"
proc add(table: var RectTable, rect: Rect) = table[rect.id] = rect
proc `$`(table: RectTable): string =
  for k,v in table:
    result.add(&"{k}: {v}\n")
  

var rt: RectTable

proc RandColor(): wColor = 
  var r: int = rand(255).shl(16)
  var g: int = rand(255).shl(8)
  var b: int = rand(255).shl(0)
  result = r or g or b

proc RandRect(id: string, maxx, maxy: Natural): Rect = 
  result = Rect(id: id, 
                pos: (rand(maxx - WRANGE.max - 1), 
                      rand(maxy - HRANGE.max - 1)), 
                size: (rand(WRANGE.min..WRANGE.max),
                       rand(HRANGE.min..HRANGE.max)), 
                selected: false,
                pencolor: RandColor(), 
                brushcolor: RandColor())

proc InitRects(maxx, maxy: Natural): RectTable =
  for i in 1..QTY:
    result.add(RandRect(&"hello{i}", maxx, maxy))

when isMainModule:
  let app = App()
  let mainFrame = MainFrame()
  discard mainFrame
  randomize()
  echo InitRects(800, 600)
  app.mainLoop()