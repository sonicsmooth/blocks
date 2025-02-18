import std/[random, tables, strformat]
from std/sequtils import toSeq
import strutils
import wNim/[wTypes]
import wNim/private/wHelper
export tables

const
  WRANGE = 25..75
  HRANGE = 25..75
  QTY* = 2

type 
  RectID* = uint
  Rotation* = enum R0, R90, R180, R270
  Rect* = ref object
    id*: RectID
    x*: int
    y*: int
    width*: int
    height*: int
    rot*: Rotation
    pencolor*: wColor
    brushcolor*: wColor
    selected*: bool
  PosWidth = tuple[x,y,width,height:int]
  RectTable* = ref Table[RectID, Rect]   # meant to be shared
  PosTable* = Table[RectID, wPoint] # meant to have value semantics
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
    "{id: \"" & $r.id & "\", " &
    "x: " & $r.x & ", " &
    "y: " & $r.y & ", " &
    "width: " & $r.width & ", " &
    "height: " & $r.height & ", " &
    "rot: " & $r.rot & ", " &
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

proc positions*(rectTable: RectTable): PosTable =
  for id,rect in rectTable:
    #result[id] = (rect.x, rect.y, rect.width, rect.height)
    result[id] = (rect.x, rect.y)

proc setPositions*[T:Table](rectTable: var RectTable, pos: T) =
  # Set rects in rectTable to positions
  for id, rect in rectTable:
    rect.x = pos[id].x
    rect.y = pos[id].y
    #rect.width = pos[id].width
    #rect.height = pos[id].height

proc size*(rect: Rect): wSize =
  (rect.width, rect.height)

proc upperLeft*(rect: wRect): wPoint =
  (rect.x, rect.y)

proc upperRight*(rect: wRect): wPoint =
  # Should have -1 offset
  # TODO: introduce upperRight< proc with offset
  (rect.x + rect.width, rect.y)

proc lowerLeft*(rect: wRect): wPoint =
  # Should have -1 offset
  (rect.x, rect.y + rect.height)

proc lowerRight*(rect: wRect): wPoint =
  # Should have -1 offset
  (rect.x + rect.width, rect.y + rect.height)

proc top*(rect: wRect): TopEdge =
  TopEdge(pt0: rect.upperLeft, pt1: rect.upperRight)

proc left*(rect: wRect): LeftEdge =
  LeftEdge(pt0: rect.upperLeft, pt1: rect.lowerLeft)

proc bottom*(rect: wRect): BottomEdge =
  BottomEdge(pt0: rect.lowerLeft, pt1: rect.lowerRight)

proc right*(rect: wRect): RightEdge =
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
  let edgeInside = (edge >= rect.left and edge <= rect.right)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.y < rect.top.pt0.y
  let pt1Outside = edge.pt1.y > rect.bottom.pt0.y
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)

proc isEdgeInRect(edge: HorizEdge, rect: wRect): bool =
  let edgeInside = (edge >= rect.top and edge <= rect.bottom)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.x < rect.left.pt0.x
  let pt1Outside = edge.pt1.x > rect.right.pt0.x
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)

proc isRectInRect*(rect1, rect2: wRect): bool = 
  # Check if any corners or edges of rect2 are within rect1
  # Generally rect1 is moving around and rect2 is part of the db
  isEdgeInRect(rect1.top,    rect2) or
  isEdgeInRect(rect1.left,   rect2) or
  isEdgeInRect(rect1.bottom, rect2) or
  isEdgeInRect(rect1.right,  rect2)

proc isRectOverRect*(rect1, rect2: wRect): bool =
  # Check if rect1 completely covers rect2
  rect1.top    < rect2.top    and
  rect1.left   < rect2.left   and
  rect1.bottom > rect2.bottom and
  rect1.right  > rect2.right

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

#TODO: make converter here

proc toRectId*(id: int): RectId =
  when RectId is int:    result = id.int
  elif RectId is int16:  result = id.int16 
  elif RectId is int32:  result = id.int32 
  elif RectId is int64:  result = id.int64
  elif RectId is uint:   result = id.uint 
  elif RectId is uint16: result = id.uint16 
  elif RectId is uint32: result = id.uint32 
  elif RectId is uint64: result = id.uint64
  elif RectId is string: result = $id
 
proc randRect*(id: RectID, screenSize: wSize): Rect = 
  let rectSizeW: int = rand(WRANGE)
  let rectSizeH: int = rand(HRANGE)
  let rectPosX:  int = rand(screenSize.width  - rectSizeW  - 1)
  let rectPosY:  int = rand(screenSize.height - rectSizeH - 1)
  proc randColor: wColor = 
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
                pencolor: randColor(), 
                brushcolor: randColor())

proc randomizeRectsAll*(table: var RectTable, size: wSize, qty: int) = 
  echo "randomize clearing table"
  table.clear()
  for i in 1..qty:
    echo "randomize adding: ", i
    let rid = toRectId(i)
    table[rid] = randRect(rid, size)

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

proc boundingBox*(rects: openArray[wRect|Rect|PosWidth]): wRect =
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

proc boundingBox*(rectTable: RectTable): wRect =
  boundingBox(rectTable.values.toSeq)

proc area*(rect: wRect|Rect): int =
  rect.width * rect.height


proc aspectRatio*(rect: wRect|Rect): float =
  rect.width.float / rect.height.float

proc aspectRatio*(rects: openArray[wRect|Rect|PosWidth]): float =
  boundingBox(rects).aspectRatio

proc aspectRatio*(rtable: RectTable): float =
  rtable.values.toSeq.aspectRatio

# fillRatio finds the ratio of fill area to bounding box
# Of a bunch of rectangles.  This can be given by 
# a seq/array of rectangles, a RectTable, or two tables --
# position and size

proc fillRatio*(rects: openArray[wRect|Rect|PosWidth]): float =
  # Find fill fillRatio of a seq of rects
  var usedArea: int
  for r in rects: 
    usedArea += r.area
  let totalArea = boundingBox(rects).area
  usedArea / totalArea

proc fillRatio*(rtable: RectTable): float =
  rtable.values.toSeq.fillRatio

# proc fillRatio*(postable: PosTable, stable: SizeTable): float =
#   posWidths(postable, stable).fillRatio

proc expand*(rect: wRect, amt: int): wRect =
  # Returns expanded wRect from given wRect
  # if amt > 0 then returned wRect is bigger than rect
  # if amt < 0 then return wRect is smaller than rect
  (x: rect.x - amt,
   y: rect.y - amt,
   width: rect.width + 2*amt,
   height: rect.height + 2*amt)
