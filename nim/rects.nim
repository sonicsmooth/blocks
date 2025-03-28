import std/[random, sets, sequtils, strutils, tables]
import wNim/[wTypes]
import wNim/private/wHelper
import randrect

type 
  RectID* = uint
  Rotation* = enum R0, R90, R180, R270
  Orientation* = enum Vertical, Horizontal
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
  scale = 3
  WRANGE = (5*scale) .. (75*scale)
  HRANGE = (5*scale) .. (75*scale)
  QTY* = 5


# Declarations
proc toFloat*(rot: Rotation): float {.inline.}
proc inc*(r: var Rotation) {.inline.}
proc dec*(r: var Rotation) {.inline.}
proc `+`*(r1, r2:Rotation): Rotation {.inline.}
proc `-`*(r1, r2:Rotation): Rotation {.inline.}



# Procs for single Rect
proc `$`*(rect: Rect): string =
  var strs: seq[string]
  for k, val in rect[].fieldPairs:
    strs.add(k & ": " & $val)
  result = strs.join(", ")

proc pos*(rect: Rect): wPoint {.inline.} =
  (rect.x, rect.y)

proc size*(rect: Rect): wSize {.inline.} =
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

proc topEdge*(rect: wRect): TopEdge =
  TopEdge(pt0: rect.upperLeft, pt1: rect.upperRight)

proc leftEdge*(rect: wRect): LeftEdge =
  LeftEdge(pt0: rect.upperLeft, pt1: rect.lowerLeft)

proc bottomEdge*(rect: wRect): BottomEdge =
  BottomEdge(pt0: rect.lowerLeft, pt1: rect.lowerRight)

proc rightEdge*(rect: wRect): RightEdge =
  RightEdge(pt0: rect.upperRight, pt1: rect.lowerRight)

proc x*(edge: VertEdge): int {.inline.} =
  edge.pt0.x

proc y*(edge: HorizEdge): int {.inline.} =
  edge.pt0.y


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
proc `<`*(edge1, edge2: VertEdge): bool {.inline.} =
  edge1.pt0.x < edge2.pt0.x
proc `<=`*(edge1, edge2: VertEdge): bool {.inline.} =
  edge1.pt0.x <= edge2.pt0.x
proc `>`*(edge1, edge2: VertEdge): bool {.inline.} =
  edge1.pt0.x > edge2.pt0.x
proc `>=`*(edge1, edge2: VertEdge): bool {.inline.} =
  edge1.pt0.x >= edge2.pt0.x
proc `==`*(edge1, edge2: VertEdge): bool {.inline.} =
  edge1.pt0.x == edge2.pt0.x
proc `<`*(edge1, edge2: HorizEdge): bool {.inline.} =
  edge1.pt0.y < edge2.pt0.y
proc `<=`*(edge1, edge2: HorizEdge): bool {.inline.} =
  edge1.pt0.y <= edge2.pt0.y
proc `>`*(edge1, edge2: HorizEdge): bool {.inline.} =
  edge1.pt0.y > edge2.pt0.y
proc `>=`*(edge1, edge2: HorizEdge): bool {.inline.} =
  edge1.pt0.y >= edge2.pt0.y
proc `==`*(edge1, edge2: HorizEdge): bool {.inline.} =
  edge1.pt0.y == edge2.pt0.y


# Procs for hit testing
proc isPointInRect*(pt: wPoint, rect: wRect): bool {.inline.} = 
    let lrcorner: wPoint = (rect.x + rect.width,
                            rect.y + rect.height)
    pt.x >= rect.x and pt.x <= lrcorner.x and
    pt.y >= rect.y and pt.y <= lrcorner.y
proc isEdgeInRect(edge: VertEdge, rect: wRect): bool {.inline.} =
  let edgeInside = (edge >= rect.leftEdge and edge <= rect.rightEdge)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.y < rect.topEdge.pt0.y
  let pt1Outside = edge.pt1.y > rect.bottomEdge.pt0.y
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)
proc isEdgeInRect(edge: HorizEdge, rect: wRect): bool {.inline.} =
  let edgeInside = (edge >= rect.topEdge and edge <= rect.bottomEdge)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.x < rect.leftEdge.pt0.x
  let pt1Outside = edge.pt1.x > rect.rightEdge.pt0.x
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)
proc isRectInRect*(rect1, rect2: wRect): bool = 
  # Check if any corners or edges of rect2 are within rect1
  # Generally rect1 is moving around and rect2 is part of the db
  isEdgeInRect(rect1.topEdge,    rect2) or
  isEdgeInRect(rect1.leftEdge,   rect2) or
  isEdgeInRect(rect1.bottomEdge, rect2) or
  isEdgeInRect(rect1.rightEdge,  rect2)
proc isRectOverRect*(rect1, rect2: wRect): bool =
  # Check if rect1 completely covers rect2
  # TODO: Use <=, >= instead of <, > ?
  rect1.topEdge    < rect2.topEdge    and
  rect1.leftEdge   < rect2.leftEdge   and
  rect1.bottomEdge > rect2.bottomEdge and
  rect1.rightEdge  > rect2.rightEdge


# Misc Procs
proc randColor: wColor = 
  let 
    b: int = rand(255) shl 16
    g: int = rand(255) shl 8
    r: int = rand(255)
  wColor(b or g or r) # 00bbggrr
proc randRect*(id: RectID, panelSize: wSize, log: bool=false): Rect = 
  var rw: int
  var rh: int
  let rectPosX:  int = rand(panelSize.width  - rw  - 1)
  let rectPosY:  int = rand(panelSize.height - rh - 1)

  if log: # Make log distribution
    let wcdf = makecdf(WRANGE.len, 100.0, 0.1) # TODO: memoize this
    let hcdf = makecdf(HRANGE.len, 100.0, 0.1) # TODO: or compile-time
    while true:
      rw = RND.sample(WRANGE.toSeq, wcdf)
      rh = RND.sample(HRANGE.toSeq, hcdf)
      if rw/rh >= (1/3) and rw/rh <= 3.0:
        break
  else: # Flat distribution
    rw = rand(WRANGE)
    rh = rand(HRANGE)

  result = Rect(id: id, 
                x: rectPosX,
                y: rectPosY,
                width: rw,
                height: rh,
                origin: (0,0),
                rot: rand(Rotation),
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
proc boundingBox*(rects: seq[wRect|Rect]): wRect =
  var left, right, top, bottom: int
  left = int.high
  right = int.low
  top = int.high
  bottom = int.low
  for r in rects:
    left   = min(left,   r.leftEdge.x)
    top    = min(top,    r.topEdge.y)
    right  = max(right,  r.rightEdge.x)
    bottom = max(bottom, r.bottomEdge.y)
  (x: left, y: top, width: right - left, height: bottom - top)
proc rotateSize*(rect: wRect|Rect, amt: Rotation): wSize =
  # Return size of rect if rotated by amt.
  # When rect.typeof is Rect, ignore current rotation
  # Basically swap the width, height if amt is 90 or 270
  case amt
  of R0:   (rect.width,  rect.height)
  of R90:  (rect.height, rect.width )
  of R180: (rect.width,  rect.height)
  of R270: (rect.height, rect.width )

proc rotate*(rect: Rect, amt: Rotation) =
  rect.rot = rect.rot + amt

proc rotate*(rect: Rect, orient: Orientation) =
  if rect.width >= rect.height:
    if orient == Horizontal: rect.rot = R0
    else: rect.rot = R90
  else:
    if orient == Horizontal: rect.rot = R90
    else: rect.rot = R0
    

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

proc toFloat*(rot: Rotation): float =
  case rot:
  of R0: 0.0
  of R90: 90.0
  of R180: 180.0
  of R270: 270.0
proc inc*(r: var Rotation) =
  case r:
  of R0:   r = R90
  of R90:  r = R180
  of R180: r = R270
  of R270: r = R0
proc dec*(r: var Rotation) =
  case r:
  of R0:   r = R270
  of R90:  r = R0
  of R180: r = R90
  of R270: r = R180
proc `+`*(r1, r2:Rotation): Rotation =
  case r1:
  of R0: r2
  of R90:
    case r2:
    of R0: R90
    of R90: R180
    of R180: R270
    of R270: R0
  of R180:
    case r2:
    of R0: R180
    of R90: R270
    of R180: R0
    of R270: R90
  of R270:
    case r2:
    of R0: R270
    of R90: R0
    of R180: R90
    of R270: R180
proc `-`*(r1, r2:Rotation): Rotation =
  case r1:
  of R0:
    case r2:
    of R0: R180
    of R90: R270
    of R180: R0
    of R270: R90
  of R90:
    case r2:
    of R0: R90
    of R90: R0
    of R180: R270
    of R270: R180
  of R180:
    case r2:
    of R0: R180
    of R90: R90
    of R180: R0
    of R270: R270
  of R270:
    case r2:
    of R0: R270
    of R90: R180
    of R180: R90
    of R270: R0
    