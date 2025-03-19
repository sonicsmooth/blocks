import std/[random, sets, tables, strformat, strutils]
import wNim/[wTypes]
import wNim/private/wHelper

type 
  RectID* = uint
  Rotation* = enum R0, R90, R180, R270
  Rect* = ref object
    id*: RectID
    x*: int
    y*: int
    width*: int
    height*: int
    origin*: wPoint
    rot*: Rotation
    pencolor*: wColor
    brushcolor*: wColor
    selected*: bool
  #PosWidth = tuple[x,y,width,height:int]
  Edge* = object of RootObj
    pt0*: wPoint
    pt1*: wPoint
  VertEdge*   = object of Edge
  HorizEdge*  = object of Edge
  TopEdge*    = object of HorizEdge
  LeftEdge*   = object of VertEdge
  BottomEdge* = object of HorizEdge
  RightEdge*  = object of VertEdge

const
  WRANGE = 25..75
  HRANGE = 25..75
  QTY* = 20


# Procs for single Rect
proc `$`*(rect: Rect): string =
  var strs: seq[string]
  for k, val in rect[].fieldPairs:
    strs.add(k & ": " & $val)
  result = strs.join("\n")

proc pos*(rect: Rect): wPoint =
  (rect.x, rect.y)

proc size*(rect: Rect): wSize =
  if rect.rot == R0 or rect.rot == R180:
    (rect.width, rect.height)
  else:
    (rect.height, rect.width)

converter wRect*(rect: Rect): wRect =
  # Implicit conversion
  if rect.rot == R0 or rect.rot == R180:
    result = (rect.x, rect.y, rect.width, rect.height)
  else:
    result = (rect.x, rect.y, rect.height, rect.width)


# Procs for single wRect
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

proc expand*(rect: wRect, amt: int): wRect =
  # Returns expanded wRect from given wRect
  # if amt > 0 then returned wRect is bigger than rect
  # if amt < 0 then returned wRect is smaller than rect
  (x: rect.x - amt,
   y: rect.y - amt,
   width: rect.width + 2*amt,
   height: rect.height + 2*amt)


# Procs for multiple Rects
proc wRects*(rects: seq[Rect]): seq[wRect] =
  # Convert to wRects.  Use converter instead?
  for rect in rects:
    result.add(rect.wRect)

proc ids*(rects: seq[Rect]): seq[RectID] =
  # Get all RectIDs
  for rect in rects:
    result.add(rect.id)


# Procs for edges
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


# Procs for hit testing
proc isPointInRect*(pt: wPoint, rect: wRect): bool = 
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
  # TODO: Use <=, >= instead of <, > ?
  rect1.top    < rect2.top    and
  rect1.left   < rect2.left   and
  rect1.bottom > rect2.bottom and
  rect1.right  > rect2.right


# Misc Procs
proc toRectId*(id: int): RectId =
  # TODO: make this less stupid
  echo "toRectId"
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
                origin: (0,0),
                rot: R0,
                selected: false,
                pencolor: randColor(), 
                brushcolor: randColor())
proc moveRectBy*(rect: Rect, delta: wPoint) =
  rect.x += delta.x
  rect.y += delta.y
proc moveRectTo*(rect: Rect, oldpos, newpos: wPoint) = 
  echo "moveRectTo"
  assert false
  rect.x = newpos.x
  rect.y = newpos.y
  #let delta = newpos - oldpos
  #moveRectBy(rect, delta)
proc boundingBox*(rects: seq[wRect|Rect]): wRect =
  var left, right, top, bottom: int
  left = int.high
  top = int.high
  for r in rects:
    left   = min(left,   r.top.pt0.x)
    top    = min(top,    r.top.pt0.y)
    right  = max(right,  r.top.pt1.x)
    bottom = max(bottom, r.bottom.pt1.y)
  (x: left, y: top, width: right - left, height: bottom - top)
proc area*(rect: wRect|Rect): int =
  rect.width * rect.height
proc aspectRatio*(rect: wRect|Rect): float =
  when typeof(rect) is Rect:
    if rect.rot == R90 or rect.rot == R180:
      rect.width.float / rect.height.float
    else:
      rect.height.float / rect.width.float
  else:
    rect.width.float / rect.height.float
proc aspectRatio*(rects: seq[wRect|Rect]): float =
  rects.boundingBox.aspectRatio
proc fillRatio*(rects: seq[wRect|Rect]): float =
  # Find ratio of total area to filled area
  var filledArea: int
  for r in rects: 
    filledArea += r.area
  let totalArea = rects.boundingBox.area
  filledArea / totalArea
proc normalizeRectCoords*(startPos, endPos: wPoint): wRect =
  # make sure that rect.x,y is always upper left
  let (sx,sy) = startPos
  let (ex,ey) = endPos
  result.x = min(sx, ex)
  result.y = min(sy, ey)
  result.width = abs(ex - sx)
  result.height = abs(ey - sy)
converter toFloat*(rot: Rotation): float =
  case rot:
  of R0: 0.0
  of R90: 90.0
  of R180: 180.0
  of R270: 270.0