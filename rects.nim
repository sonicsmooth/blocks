import std/[random, tables, strformat]
import wNim/[wTypes]
import wNim/private/wHelper
export tables

const
  WRANGE = (min:25, max:75)
  HRANGE = (min:25, max:75)
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
  RectTable* = Table[RectID, Rect]

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

proc RandColor: wColor = 
  # 00bbggrr
  let 
    a: int = 0x7f      shl 24
    b: int = rand(255) shl 16
    g: int = rand(255) shl 8
    r: int = rand(255)
  result = wColor(a or b or g or r)
  #echo &"{result:08x}"

proc RandRect*(id: RectID, size: wSize): Rect = 
  result = Rect(id: id, 
                pos: (rand(size.width  - WRANGE.max - 1), 
                      rand(size.height - HRANGE.max - 1)), 
                size: (rand(WRANGE.min..WRANGE.max),
                       rand(HRANGE.min..HRANGE.max)), 
                selected: false,
                pencolor: RandColor(), 
                brushcolor: RandColor())

proc RandomizeRects*(refTable: ref RectTable, size: wSize, qty:int) = 
  refTable.clear()
  for i in 1..qty:
    refTable[].add(RandRect($i, size))

# This seems to work with rect: Rect also
proc MoveRectDelta(rect: var Rect, delta: wPoint) =
  rect.pos = rect.pos + delta

proc MoveRect*(rect: var Rect, oldpos, newpos: wPoint) = 
  let delta = newpos - oldpos
  MoveRectDelta(rect, delta)