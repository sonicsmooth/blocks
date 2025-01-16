import std/[random, tables, strformat]
import wNim/[wTypes]
import wNim/private/wHelper
export tables

const
  WRANGE = 25..75
  HRANGE = 25..75
  QTY* = 10

type 
  RectID* = string
  Rect* = ref object
    id*: RectID
    pos*: wPoint
    size*: wSize
    pencolor*: wColor
    brushcolor*: wColor
    selected*: bool
  RectTable* = ref Table[RectID, Rect]

proc `$`*(r: Rect): string =
  result =
    "{id: \"" & r.id & "\", " &
    "pos: " & $r.pos & ", " &
    "size: " & $r.size & ", " &
    "pencolor: " & &"0x{r.pencolor:0x}" & ", " &
    "brushcolor: " & &"0x{r.brushcolor:0x}" & ", " &
    "selected: " & $r.selected & "}"

proc add*(table: var RectTable, rect: Rect) = 
  table[rect.id] = rect

proc `$`*(table: RectTable): string =
  for k,v in table:
    result.add(&"{k}: {v}\n")

proc ToRect*(rect: Rect): wRect =
  (rect.pos.x, rect.pos.y, rect.size.width, rect.size.height)

proc wRect*(rect: Rect): wRect =
  (rect.pos.x, rect.pos.y, rect.size.width, rect.size.height)

proc RandColor: wColor = 
  # 00bbggrr
  let 
    b: int = rand(255) shl 16
    g: int = rand(255) shl 8
    r: int = rand(255)
  result = wColor(b or g or r)

proc RandRect(id: RectID, screenSize: wSize): Rect = 
  let rectSize: wSize = (rand(WRANGE), rand(HRANGE))
  let rectPos: wPoint = (rand(screenSize.width  - rectSize.width  - 1),
                         rand(screenSize.height - rectSize.height - 1))
  result = Rect(id: id, 
                size: rectSize,
                pos: rectPos,
                selected: false,
                pencolor: RandColor(), 
                brushcolor: RandColor())

proc RandomizeRectsAll*(table: var RectTable, size: wSize, qty:int) = 
  table.clear()
  for i in 1..qty:
    table.add(RandRect($i, size))

proc RandomizeRectsPos*(table: RectTable, screenSize: wSize) =
  for id, rect in table:
    rect.pos = (rand(screenSize.width  - rect.size.width  - 1),
                rand(screenSize.height - rect.size.height - 1))

# This works because Rect is a ref object
proc MoveRectDelta(rect: Rect, delta: wPoint) =
  rect.pos = rect.pos + delta

proc MoveRect*(rect: Rect, oldpos, newpos: wPoint) = 
  let delta = newpos - oldpos
  MoveRectDelta(rect, delta)