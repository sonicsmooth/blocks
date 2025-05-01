import std/[sugar, random, sets, sequtils, strutils, tables]
import wNim/wTypes
import wNim/private/wHelper
from sdl2 import Rect
import randrect
import colors

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
    penColor*: ColorU32
    brushColor*: ColorU32
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
  scale = 10
  WRANGE* = (5*scale) .. (25*scale)
  HRANGE* = (5*scale) .. (25*scale)
  WRNGby2 = WRANGE.a + (WRANGE.b - WRANGE.a) div 2
  HRNGby2 = HRANGE.a + (HRANGE.b - HRANGE.a) div 2

# TODO: Change all domain wRects to sdl2.Rect

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
  # Returns width and height after accounting for rotation
  if rect.rot == R0 or rect.rot == R180:
    (rect.width, rect.height)
  else:
    (rect.height, rect.width)

proc towRectNoRot*(rect: Rect): wRect {.inline.} =
  # Explicit conversion to wRect.
  # Bounds are corrected for origin
  # Bounds are not corrected for rotation
  (rect.x - rect.origin.x, 
   rect.y - rect.origin.y, 
   rect.width, 
   rect.height)

converter toRect*(rect: wRect): sdl2.Rect =
  (rect.x, 
   rect.y, 
   rect.width, 
   rect.height)
converter towRect*(rect: sdl2.Rect): wRect =
  (rect.x, 
   rect.y, 
   rect.w, 
   rect.h)

converter wRect*(rect: rects.Rect): wRect {.inline} =
  # Returns barebones rectangle x,y,w,h after rotation
  # Explicit conversion to wRect.
  # Bounds are corrected for origin
  # Bounds are also corrected for rotation
  let
    (w, h)   = (rect.width,    rect.height  )
    (x, y)   = (rect.x,        rect.y       )
    (ox, oy) = (rect.origin.x, rect.origin.y)
  case rect.rot:
  of R0:   (x - ox,     y - oy,     w, h)
  of R90:  (x - oy,     y + ox - w, h, w)
  of R180: (x + ox - w, y + oy - h, w, h)
  of R270: (x + oy - h, y - ox,     h, w)

# Todo: Add converter Rect

proc originXLeft*(rect: Rect): int =
  # Horizontal distance from left edge to origin after rotation
  case rect.rot:
  of R0:   rect.origin.x
  of R90:  rect.origin.y
  of R180: rect.width  - rect.origin.x
  of R270: rect.height - rect.origin.y

proc originYUp*(rect: Rect): int =
  # Vertical distance from top edge to origin after rotation
  case rect.rot:
  of R0:   rect.origin.y
  of R90:  rect.width  - rect.origin.x
  of R180: rect.height - rect.origin.y
  of R270: rect.origin.x

# Procs for single wRect
# Not including -1, etc., because right = x + width.
# eg for width=2 rect at 0, right edge = 2, not 1+1
proc upperLeft*(rect: wRect): wPoint =
  (rect.x, rect.y)
proc upperRight*(rect: wRect): wPoint =
  (rect.x + rect.width, rect.y)
proc lowerLeft*(rect: wRect): wPoint =
  (rect.x, rect.y + rect.height)
proc lowerRight*(rect: wRect): wPoint =
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
# TODO: remove .pt0
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
    let lrcorner = rect.lowerRight
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

  let brushColor = randColor() #ColorU32 0x7f_ff_00_00 # half red
  let penColor   = brushColor.colordiv(2)
  result = Rect(id: id, 
                x: rectPosX,
                y: rectPosY,
                width: rw div 2,
                height: rh div 2,
                origin: (10, 20),
                rot: rand(Rotation),
                selected: false,
                penColor: penColor,
                brushColor: brushColor)

proc moveRectBy*(rect: Rect, delta: wPoint) =
  rect.x += delta.x
  rect.y += delta.y

proc moveRectTo*(rect: Rect, oldpos, newpos: wPoint) = 
  echo "moveRectTo"
  assert false
  rect.x = newpos.x
  rect.y = newpos.y

proc boundingBox*(rects: seq[wRect|Rect]): wRect {.inline.} =
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
    

proc area*(rect: rects.Rect): int {.inline.} =
  rect.width * rect.height

proc area*(rect: sdl2.Rect): int {.inline.} =
  rect.w * rect.h

proc aspectRatio*(rect: wRect|Rect): float =
  when typeof(rect) is Rect:
    #Todo: rect.wrect
    if rect.rot == R90 or rect.rot == R180:
      rect.width.float / rect.height.float
    else:
      rect.height.float / rect.width.float
  else:
    rect.width.float / rect.height.float

proc aspectRatio*(rects: seq[wRect|Rect]): float =
  rects.boundingBox.aspectRatio

proc fillArea*(rects: seq[wRect|Rect]): int =
  for r in rects:
    result += r.area

proc fillRatio*(rects: seq[wRect|Rect]): float =
  # Find ratio of total area to filled area
  rects.fillArea.float / rects.boundingBox.area.float

proc normalizeRectCoords*(startPos, endPos: wPoint): sdl2.Rect =
  # make sure that rect.x,y is always upper left
  let (sx,sy) = startPos
  let (ex,ey) = endPos
  result.x = min(sx, ex)
  result.y = min(sy, ey)
  result.w = abs(ex - sx)
  result.h = abs(ey - sy)

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
    