import std/[random, tables, strformat]
import wNim/[wTypes]
export tables

const
  WRANGE = (min:15, max:50)
  HRANGE = (min:15, max:50)
  QTY = 10

type 
  Rect* = ref object
    id*: string
    pos*: wPoint
    size*: wSize
    pencolor*: wColor
    brushcolor*: wColor
    selected*: bool
  RectTable* = Table[string, Rect]

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

proc RandColor*: wColor = 
  let 
    r: int = rand(255).shl(16)
    g: int = rand(255).shl(8)
    b: int = rand(255)
  result = wColor(r or g or b)

proc RandRect*(id: string, size: wSize): Rect = 
  result = Rect(id: id, 
                pos: (rand(size.width  - WRANGE.max - 1), 
                      rand(size.height - HRANGE.max - 1)), 
                size: (rand(WRANGE.min..WRANGE.max),
                       rand(HRANGE.min..HRANGE.max)), 
                selected: false,
                pencolor: RandColor(), 
                brushcolor: RandColor())

proc InitRects*(size: wSize): RectTable =
  # wSize is max extent of rects
  for i in 1..QTY:
    result.add(RandRect($i, size))
