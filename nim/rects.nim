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
    x*: int
    y*: int
    width*: int
    height*: int
    id*: RectID
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


proc `$`*(r: Rect): string =
  result =
    "{id: \"" & r.id & "\", " &
    "x: " & $r.x & ", " &
    "y: " & $r.y & ", " &
    "width: " & $r.width & ", " &
    "height: " & $r.height & ", " &
    "pencolor: " & &"0x{r.pencolor:0x}" & ", " &
    "brushcolor: " & &"0x{r.brushcolor:0x}" & ", " &
    "selected: " & $r.selected & "}"

proc `$`*(table: RectTable): string =
  for k,v in table:
    result.add(&"{k}: {v}\n")

proc `[]`*(table: RectTable, idxs: openArray[RectID]): seq[Rect] =
  for idx in idxs:
    result.add(table[idx])

proc wRect*(rect: Rect): wRect =
  result = (rect.x, rect.y, rect.width, rect.height)

proc wRects*(rects: openArray[Rect]): seq[wRect] =
  # Returns seq of wRects from seq of Rects
  for rect in rects:
    result.add(rect.wRect)

proc ids*(rects: openArray[Rect]): seq[RectID] =
  # Return seq of RectIDs from seq of Rects
  for rect in rects:
    result.add(rect.id)

proc pos*(rect: Rect): wPoint =
  (rect.x, rect.y)

proc size*(rect: Rect): wSize =
  (rect.width, rect.height)

proc upperLeft*(rect: wRect): wPoint =
  (rect.x, rect.y)

proc upperRight*(rect: wRect): wPoint =
  (rect.x + rect.width, rect.y)

proc lowerLeft*(rect: wRect): wPoint =
  (rect.x, rect.y + rect.height)

proc lowerRight*(rect: wRect): wPoint =
  (rect.x + rect.width, rect.y + rect.height)

proc Top*(rect: wRect): TopEdge =
  TopEdge(pt0: rect.upperLeft, pt1: rect.upperRight)

proc Left*(rect: wRect): LeftEdge =
  LeftEdge(pt0: rect.upperLeft, pt1: rect.lowerLeft)

proc Bottom*(rect: wRect): BottomEdge =
  BottomEdge(pt0: rect.lowerLeft, pt1: rect.lowerRight)

proc Right*(rect: wRect): RightEdge =
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

proc isPointInRect(pt: wpoint, rect: wRect): bool = 
    let lrcorner: wPoint = (rect.x + rect.width,
                            rect.y + rect.height)
    pt.x >= rect.x and pt.x <= lrcorner.x and
    pt.y >= rect.y and pt.y <= lrcorner.y

proc isEdgeInRect(edge: VertEdge, rect: wRect): bool =
  let edgeInside = (edge >= rect.Left and edge <= rect.Right)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.y < rect.Top.pt0.y
  let pt1Outside = edge.pt1.y > rect.Bottom.pt0.y
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)

proc isEdgeInRect(edge: HorizEdge, rect: wRect): bool =
  let edgeInside = (edge >= rect.Top and edge <= rect.Bottom)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.x < rect.Left.pt0.x
  let pt1Outside = edge.pt1.x > rect.Right.pt0.x
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)

proc isRectInRect*(rect1, rect2: wRect): bool = 
  # Check if any corners or edges of rect2 are within rect1
  # Generally rect1 is moving around and rect2 is part of the db
  isEdgeInRect(rect1.Top,    rect2) or
  isEdgeInRect(rect1.Left,   rect2) or
  isEdgeInRect(rect1.Bottom, rect2) or
  isEdgeInRect(rect1.Right,  rect2)

proc isRectOverRect*(rect1, rect2: wRect): bool =
  # Check if rect1 completely covers rect2
  rect1.Top    < rect2.Top    and
  rect1.Left   < rect2.Left   and
  rect1.Bottom > rect2.Bottom and
  rect1.Right  > rect2.Right

proc ptInRects*(pt: wPoint, table: RectTable): seq[RectID] = 
  # Returns seq of Rect IDs from table whose rect 
  # surrounds or contacts pt
  # Optimization? -- return after first one
  for id, rect in table:
      if isPointInRect(pt, rect.wRect):
        result.add(id)

proc rectInRects*(rect: wRect, table: RectTable): seq[RectID] = 
  # Return seq of Rect IDs from table that intersect rect
  # Return seq also includes rect
  # Typically rect is moving around and touches objs in table
  # Or rect is a bounding box and we're looking for where 
  # it touches other blocks
  for id, tabRect in table:
    if isRectInRect(rect, tabRect.wRect) or 
       isRectOverRect(rect, tabRect.wRect):
      result.add(id)

proc rectInRects*(rectId: RectID, table: RectTable): seq[RectID] = 
  rectInRects(table[rectId].wRect, table)



proc RandRect(id: RectID, screenSize: wSize): Rect = 
  let rectSizeW: int = rand(WRANGE)
  let rectSizeH: int = rand(HRANGE)
  let rectPosX:  int = rand(screenSize.width  - rectSizeW  - 1)
  let rectPosY:  int = rand(screenSize.height - rectSizeH - 1)
  proc RandColor: wColor = 
    let 
      b: int = rand(255) shl 16
      g: int = rand(255) shl 8
      r: int = rand(255)
    wColor(b or g or r) # 00bbggrr

  result = Rect(id: id, 
                x: rectPosX,
                y: rectPosY,
                width: rectSizeW,
                height: rectSizeH,
                selected: false,
                pencolor: RandColor(), 
                brushcolor: RandColor())

proc randomizeRectsAll*(table: var RectTable, size: wSize, qty: int) = 
  table.clear()
  for i in 1..qty:
    let rect = RandRect($i, size)
    table[rect.id] = rect
    #table.add(RandRect($i, size))

proc randomizeRectsPos*(table: RectTable, screenSize: wSize) =
  for id, rect in table:
    rect.x = rand(screenSize.width  - rect.width  - 1)
    rect.y = rand(screenSize.height - rect.height - 1)

proc moveRectBy*(rect: Rect, delta: wPoint) =
  rect.x += delta.x
  rect.y += delta.y

proc moveRect*(rect: Rect, oldpos, newpos: wPoint) = 
  let delta = newpos - oldpos
  moveRectBy(rect, delta)

proc boundingBox*(rects: openArray[wRect]): wRect =
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

proc boundingBox*(rects: openArray[Rect]): wRect =
  boundingBox(rects.wRects)

proc expand*(rect: wRect, amt: int): wRect =
  # Returns expanded wRect from given wRect
  # if amt > 0 then returned wRect is bigger than rect
  # if amt < 0 then return wRect is smaller than rect
  (x: rect.x - amt,
   y: rect.y - amt,
   width: rect.width + 2*amt,
   height: rect.height + 2*amt)
  