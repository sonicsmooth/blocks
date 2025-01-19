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
  Edge* = object of RootObj
    pt0*: wPoint
    pt1*: wPoint
  VertEdge*   = object of Edge
  HorizEdge*  = object of Edge
  TopEdge*    = object of HorizEdge
  LeftEdge*   = object of VertEdge
  BottomEdge* = object of HorizEdge
  RightEdge*  = object of VertEdge

proc `[]`*(table: RectTable, idxs: seq[RectID]): seq[Rect] =
  for idx in idxs:
    result.add(table[idx])

proc `[]`*[S](table: RectTable, idxs: array[S, Rect]): array[S, Rect] = 
  for i,idx in idxs:
    result[i] = table[idx]


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

# proc toWRect*(rect: Rect): wRect =
#   (rect.pos.x, rect.pos.y, rect.size.width, rect.size.height)

proc wRect*(rect: Rect): wRect =
  (rect.pos.x, rect.pos.y, rect.size.width, rect.size.height)

proc wRects*(rects: seq[Rect]): seq[wRect] =
  for rect in rects:
    result.add(rect.wRect)

proc upperLeft*(rect: Rect): wPoint =
  rect.pos

proc upperRight*(rect: Rect): wPoint =
  (rect.pos.x + rect.size.width, rect.pos.y)

proc lowerLeft*(rect: Rect): wPoint =
  (rect.pos.x, rect.pos.y + rect.size.height)

proc lowerRight*(rect: Rect): wPoint =
  (rect.pos.x + rect.size.width, rect.pos.y + rect.size.height)

proc Top*(rect: Rect): TopEdge =
  TopEdge(pt0: rect.upperLeft, pt1: rect.upperRight)

proc Left*(rect: Rect): LeftEdge =
  LeftEdge(pt0: rect.upperLeft, pt1: rect.lowerLeft)

proc Bottom*(rect: Rect): BottomEdge =
  BottomEdge(pt0: rect.lowerLeft, pt1: rect.lowerRight)

proc Right*(rect: Rect): RightEdge =
  RightEdge(pt0: rect.upperRight, pt1: rect.lowerRight)

# Comparators assume edges are truly vertical or horizontal
# So we only look at pt0
proc `<`*(edge1, edge2: VertEdge): bool =
  edge1.pt0.x < edge2.pt0.x

proc `<=`*(edge1, edge2: VertEdge): bool =
  edge1.pt0.x <= edge2.pt0.x

proc `>`*(edge1, edge2: VertEdge): bool =
  edge1.pt0.x > edge2.pt0.x

proc `>=`*(edge1, edge2: VertEdge): bool =
  edge1.pt0.x >= edge2.pt0.x

proc `==`*(edge1, edge2: VertEdge): bool =
  edge1.pt0.x == edge2.pt0.x

proc `<`*(edge1, edge2: HorizEdge): bool =
  edge1.pt0.y < edge2.pt0.y

proc `<=`*(edge1, edge2: HorizEdge): bool =
  edge1.pt0.y <= edge2.pt0.y

proc `>`*(edge1, edge2: HorizEdge): bool =
  edge1.pt0.y > edge2.pt0.y

proc `>=`*(edge1, edge2: HorizEdge): bool =
  edge1.pt0.y >= edge2.pt0.y

proc `==`*(edge1, edge2: HorizEdge): bool =
  edge1.pt0.y == edge2.pt0.y

proc isPointInRect(pt: wpoint, rect: Rect): bool = 
    let lrcorner: wPoint = (rect.pos.x + rect.size.width,
                            rect.pos.y + rect.size.height)
    pt.x >= rect.pos.x and pt.x <= lrcorner.x and
    pt.y >= rect.pos.y and pt.y <= lrcorner.y

proc isEdgeInRect(edge: VertEdge, rect: Rect): bool =
  let edgeInside = (edge >= rect.Left and edge <= rect.Right)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.y < rect.Top.pt0.y
  let pt1Outside = edge.pt1.y > rect.Bottom.pt0.y
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)

proc isEdgeInRect(edge: HorizEdge, rect: Rect): bool =
  let edgeInside = (edge >= rect.Top and edge <= rect.Bottom)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.x < rect.Left.pt0.x
  let pt1Outside = edge.pt1.x > rect.Right.pt0.x
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)

proc isRectInRect*(rect1, rect2: Rect): bool = 
  # Check if any corners or edges of rect2 are within rect1
  # Generally rect1 is moving around and rect2 is part of the db
  isEdgeInRect(rect1.Top,    rect2) or
  isEdgeInRect(rect1.Left,   rect2) or
  isEdgeInRect(rect1.Bottom, rect2) or
  isEdgeInRect(rect1.Right,  rect2)

proc ptInRects*(pt: wPoint, table: RectTable): seq[RectID] = 
  # Returns seq of Rect IDs whose rect surrounds or contacts pt
  # Optimization? -- return after first one
  for id, rect in table:
      if isPointInRect(pt, rect):
        result.add(id)

proc rectInRects*(rect: Rect, table: RectTable): seq[RectID] = 
  # Return seq of Rect IDs from table that intersect rect
  # Return seq also includes rect
  # Typically rect is moving around and touches objs in table
  for id, tabRect in table:
    if isRectInRect(rect, tabRect):
      result.add(id)

proc rectInRects*(rectId: RectID, table: RectTable): seq[RectID] = 
  rectInRects(table[rectId], table)



proc RandRect(id: RectID, screenSize: wSize): Rect = 
  let rectSize: wSize = (rand(WRANGE), rand(HRANGE))
  let rectPos: wPoint = (rand(screenSize.width  - rectSize.width  - 1),
                         rand(screenSize.height - rectSize.height - 1))
  proc RandColor: wColor = 
    let 
      b: int = rand(255) shl 16
      g: int = rand(255) shl 8
      r: int = rand(255)
    wColor(b or g or r) # 00bbggrr

  result = Rect(id: id, 
                size: rectSize,
                pos: rectPos,
                selected: false,
                pencolor: RandColor(), 
                brushcolor: RandColor())

proc randomizeRectsAll*(table: var RectTable, size: wSize, qty:int) = 
  table.clear()
  for i in 1..qty:
    table.add(RandRect($i, size))

proc randomizeRectsPos*(table: RectTable, screenSize: wSize) =
  for id, rect in table:
    rect.pos = (rand(screenSize.width  - rect.size.width  - 1),
                rand(screenSize.height - rect.size.height - 1))

# This works because Rect is a ref object
proc moveRectDelta(rect: Rect, delta: wPoint) =
  rect.pos = rect.pos + delta

proc moveRect*(rect: Rect, oldpos, newpos: wPoint) = 
  let delta = newpos - oldpos
  moveRectDelta(rect, delta)

proc boundingBox*(rects: seq[wRect]): wRect =
  # Bbox from a bunch of wRects
  var left = rects[0].x
  var top = rects[0].y
  var right = rects[0].x + rects[0].width
  var bottom = rects[0].y + rects[0].height
  for rect in rects[1..rects.high]:
    left = min(left, rect.x)
    top = min(top, rect.y)
    right = max(right, rect.x+rect.width)
    bottom = max(bottom, rect.y+rect.height)
  (x:left, y: top, width: right - left, height: bottom - top)

proc boundingBox*(rects: seq[Rect]): wRect =
  # Bbox from a bunch of Rects
  boundingBox(wRects(rects))

proc expand*(rect: wRect, amt: int): wRect =
  (x: rect.x - amt,
   y: rect.y - amt,
   width: rect.width + 2*amt,
   height: rect.height + 2*amt)
  
proc expand*(rect: Rect, amt: int): wRect =
  rect.wRect.expand(amt)