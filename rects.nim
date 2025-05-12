import std/[sugar, random, sets, sequtils, strutils, tables]
import wNim/wTypes
import wNim/private/wHelper
from sdl2 import Rect, Point
import randrect
import colors

# Generally,
#  rects.Rect is a domain rectangle in the database
#  PRect is a graphical literal rectangle

#[
Each box is a pixel.
Box origin is (5,12)
Box width and height are 3
Edges (x) are *in* the Rect
     5 6 7
    ┌─┬─┬─┐
 12 │x│x│x│
    ├─┼─┼─┤
 13 │x│ │x│
    ├─┼─┼─┤
 14 │x│x│x│
    └─┴─┴─┘  ]#


#[
A few ways to specify rectangle.
These all require 6 integers.
In all cases x,y are extrinsic to the rectangle 
and can be in a different part of the database
1. x,y    -- location of rect's crosshair
   w,h    -- width, height
   origin -- offset of crosshair from upper left
2. x,y    -- location of upper left
   w,h    -- width, height
   origin -- location of rect's crosshair
3. x,y            -- location of origin
   x1, y2, x2, y2 -- location of corners relative to origin
]#
#


type 
  RectID* = uint
  Rotation* = enum R0, R90, R180, R270
  Orientation* = enum Vertical, Horizontal
  Size* = tuple[w: int, h: int]
  Point* = sdl2.Point
  PRect* = sdl2.Rect # pixel rect
  Rect* = ref object
    x*: int
    y*: int
    w*: int
    h*: int
    id*: RectID
    label*: string
    origin*: Point
    rot*: Rotation
    penColor*: ColorU32
    brushColor*: ColorU32
    selected*: bool
  SomeRect = Rect | PRect
  Edge* = object of RootObj
    pt0*: Point
    pt1*: Point
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




# Declarations
proc `$`*(rect: Rect): string
proc `$`*(rect: PRect): string
proc `==`*(a, b: Rect): bool
proc pos*(rect: SomeRect): Point {.inline.}
proc size*(rect: SomeRect): Size {.inline.}
proc toRectNoRot*(rect: Rect): PRect {.inline.}
converter toRect*(rect: Rect): PRect {.inline.}
converter toRect*(rect: PRect): PRect {.inline.}
proc originXLeft*(rect: Rect): int
proc originYUp*(rect: Rect): int
proc left*(rect: SomeRect): int
proc right*(rect: SomeRect): int
proc top*(rect: SomeRect): int
proc bottom*(rect: SomeRect): int
proc upperLeft*(rect: SomeRect):  Point
proc upperRight*(rect: SomeRect): Point
proc lowerLeft*(rect: SomeRect):  Point
proc lowerRight*(rect: SomeRect): Point
converter toTopEdge*(rect: SomeRect):    TopEdge
converter toLeftEdge*(rect: SomeRect):   LeftEdge
converter toBottomEdge*(rect: SomeRect): BottomEdge
converter toRightEdge*(rect: SomeRect):  RightEdge
proc x*(edge: VertEdge ): int {.inline.}
proc y*(edge: HorizEdge): int {.inline.}
proc ids*(rects: openArray[Rect]): seq[RectID]
proc `<`* (edge1, edge2: VertEdge):  bool {.inline.}
proc `<=`*(edge1, edge2: VertEdge):  bool {.inline.}
proc `>`* (edge1, edge2: VertEdge):  bool {.inline.}
proc `>=`*(edge1, edge2: VertEdge):  bool {.inline.}
proc `==`*(edge1, edge2: VertEdge):  bool {.inline.}
proc `<`* (edge1, edge2: HorizEdge): bool {.inline.}
proc `<=`*(edge1, edge2: HorizEdge): bool {.inline.}
proc `>`* (edge1, edge2: HorizEdge): bool {.inline.}
proc `>=`*(edge1, edge2: HorizEdge): bool {.inline.}
proc `==`*(edge1, edge2: HorizEdge): bool {.inline.}
proc isPointInRect*[T:PRect](pt: Point, rect: T): bool {.inline.}
proc isEdgeInRect[T:PRect](edge: VertEdge, rect: T): bool {.inline.}
proc isEdgeInRect[T:PRect](edge: HorizEdge, rect: T): bool {.inline.}
proc isRectInRect*[T:PRect](rect1, rect2: T): bool 
proc isRectOverRect*[T:PRect](rect1, rect2: T): bool
proc randRect*(id: RectID, panelSize: Size, log: bool=false): Rect 
proc moveRectBy*[T:SomeRect](rect: T, delta: Point)
proc moveRectTo*[T:SomeRect](rect: T, pos: Point) 
proc boundingBox*[T:SomeRect](rects: openArray[T]): PRect {.inline.}
proc rotateSize*[T:PRect](rect: T, amt: Rotation): Size
proc rotate*(rect: Rect, amt: Rotation)
proc rotate*(rect: Rect, orient: Orientation)
proc area*(rect: SomeRect): int {.inline.}
proc aspectRatio*(rect: SomeRect): float
proc aspectRatio*[T:SomeRect](rects: seq[T]): float
proc fillArea*[T:SomeRect](rects: seq[T]): int
proc fillRatio*[T:SomeRect](rects: seq[T]): float
proc normalizeRectCoords*(startPos, endPos: Point): PRect
proc toFloat*(rot: Rotation): float {.inline.}
proc inc*(r: var Rotation) {.inline.}
proc dec*(r: var Rotation) {.inline.}
proc `+`*(r1, r2:Rotation): Rotation {.inline.}
proc `-`*(r1, r2:Rotation): Rotation {.inline.}
converter toSize*(size: wSize): Size
converter toPoint*(pt: wPoint): Point {.inline.}




# Procs for single Rect
proc `$`*(rect: Rect): string =
  var strs: seq[string]
  for k, val in rect[].fieldPairs:
    strs.add(k & ": " & $val)
  result = strs.join(", ")

proc `$`*(rect: PRect): string =
  var strs: seq[string]
  for k, val in rect.fieldPairs:
    strs.add(k & ": " & $val)
  result = strs.join(", ")

proc `==`*(a, b: Rect): bool =
  # Don't include id, just position, size and rotation
  a.x == b.x and
  a.y == b.y and
  a.w == b.w and
  a.h == b.h and
  a.origin == b.origin and
  a.rot == b.rot


proc pos*(rect: SomeRect): Point {.inline.} =
  # Returns Rect's origin.
  # Returns PRect's upper left corner 
  (rect.x, rect.y)
proc size*(rect: SomeRect): Size {.inline.} =
  # Returns width and height after accounting for rotation
  when typeof(rect) is rects.Rect:
    if rect.rot == R0 or rect.rot == R180:
      (rect.w, rect.h)
    else:
      (rect.h, rect.w)
  elif typeof(rect) is PRect:
    (rect.h, rect.w)
proc toRectNoRot*(rect: Rect): PRect {.inline.} =
  # Explicit conversion from rects.Rect to PRect.
  # Bounds are corrected for origin
  # Bounds are not corrected for rotation
  (rect.x - rect.origin.x, 
   rect.y - rect.origin.y, 
   rect.w, 
   rect.h)
converter toRect*(rect: Rect): PRect =
  # Implicit conversion from rects.Rect to PRect.
  # Returns barebones rectangle x,y,w,h after rotation
  # Explicit conversion to wRect.
  # Bounds are corrected for origin
  # Bounds are also corrected for rotation
  let
    (w, h)   = (rect.w.cint,        rect.h.cint  )
    (x, y)   = (rect.x.cint,        rect.y.cint  )
    (ox, oy) = (rect.origin.x.cint, rect.origin.y.cint)
  case rect.rot:
  of R0:   return (x - ox,     y - oy,     w, h)
  of R90:  return (x - oy,     y + ox - w, h, w)
  of R180: return (x + ox - w, y + oy - h, w, h)
  of R270: return (x + oy - h, y - ox,     h, w)
converter toRect*(rect: PRect): PRect =
  rect
proc originXLeft*(rect: Rect): int =
  # Horizontal distance from left edge to origin after rotation
  case rect.rot:
  of R0:   rect.origin.x
  of R90:  rect.origin.y
  of R180: rect.w - rect.origin.x
  of R270: rect.h - rect.origin.y
proc originYUp*(rect: Rect): int =
  # Vertical distance from top edge to origin after rotation
  case rect.rot:
  of R0:   rect.origin.y
  of R90:  rect.w  - rect.origin.x
  of R180: rect.h - rect.origin.y
  of R270: rect.origin.x

# Procs for single Rect
proc left*(rect: SomeRect): int =
  rect.LeftEdge.x
proc right*(rect: SomeRect): int =
  rect.RightEdge.x
proc top*(rect: SomeRect): int =
  rect.TopEdge.y
proc bottom*(rect: SomeRect): int =
  rect.BottomEdge.y
proc upperLeft*(rect: SomeRect):  Point = 
  let r = rect.toRect
  (r.x, r.y)
proc upperRight*(rect: SomeRect): Point = 
  let r = rect.toRect
  (r.x + r.w, r.y)
proc lowerLeft*(rect: SomeRect):  Point = 
  let r = rect.toRect
  (r.x, r.y + r.h)
proc lowerRight*(rect: SomeRect): Point = 
  let r = rect.toRect
  (r.x + r.w, r.y + r.h)
converter toTopEdge*(rect: SomeRect):    TopEdge =
  result.pt0 = rect.upperLeft
  result.pt1 = rect.upperRight
converter toLeftEdge*(rect: SomeRect):   LeftEdge =
  result.pt0 = rect.upperLeft
  result.pt1 = rect.lowerLeft
converter toBottomEdge*(rect: SomeRect): BottomEdge =
  result.pt0 = rect.lowerLeft
  result.pt1 = rect.lowerRight
converter toRightEdge*(rect: SomeRect):  RightEdge =
  result.pt0 = rect.upperRight
  result.pt1 = rect.lowerRight
proc x*(edge: VertEdge ): int {.inline.} = edge.pt0.x
proc y*(edge: HorizEdge): int {.inline.} = edge.pt0.y


# Procs for multiple Rects
proc ids*(rects: openArray[Rect]): seq[RectID] =
  # Get all RectIDs
  for rect in rects:
    result.add(rect.id)


# Procs for edges
# Comparators assume edges are truly vertical or horizontal
# So we only look at pt0
proc `<`* (edge1, edge2: VertEdge):  bool {.inline.} = edge1.x <  edge2.x
proc `<=`*(edge1, edge2: VertEdge):  bool {.inline.} = edge1.x <= edge2.x
proc `>`* (edge1, edge2: VertEdge):  bool {.inline.} = edge1.x >  edge2.x
proc `>=`*(edge1, edge2: VertEdge):  bool {.inline.} = edge1.x >= edge2.x
proc `==`*(edge1, edge2: VertEdge):  bool {.inline.} = edge1.x == edge2.x
proc `<`* (edge1, edge2: HorizEdge): bool {.inline.} = edge1.y <  edge2.y
proc `<=`*(edge1, edge2: HorizEdge): bool {.inline.} = edge1.y <= edge2.y
proc `>`* (edge1, edge2: HorizEdge): bool {.inline.} = edge1.y >  edge2.y
proc `>=`*(edge1, edge2: HorizEdge): bool {.inline.} = edge1.y >= edge2.y
proc `==`*(edge1, edge2: HorizEdge): bool {.inline.} = edge1.y == edge2.y


# Procs for hit testing operate on graphical PRects
proc isPointInRect*[T:PRect](pt: Point, rect: T): bool {.inline.} = 
    let lrcorner = rect.lowerRight
    pt.x >= rect.x and pt.x <= lrcorner.x and
    pt.y >= rect.y and pt.y <= lrcorner.y
proc isEdgeInRect[T:PRect](edge: VertEdge, rect: T): bool {.inline.} =
  let edgeInside = (edge >= rect.LeftEdge and edge <= rect.RightEdge)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.y < rect.TopEdge.pt0.y
  let pt1Outside = edge.pt1.y > rect.BottomEdge.pt0.y
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)
proc isEdgeInRect[T:PRect](edge: HorizEdge, rect: T): bool {.inline.} =
  let edgeInside = (edge >= rect.TopEdge and edge <= rect.BottomEdge)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.x < rect.LeftEdge.pt0.x
  let pt1Outside = edge.pt1.x > rect.RightEdge.pt0.x
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)
proc isRectInRect*[T:PRect](rect1, rect2: T): bool = 
  # Check if any corners or edges of rect2 are within rect1
  # Generally rect1 is moving around and rect2 is part of the db
  isEdgeInRect(rect1.TopEdge,    rect2) or
  isEdgeInRect(rect1.LeftEdge,   rect2) or
  isEdgeInRect(rect1.BottomEdge, rect2) or
  isEdgeInRect(rect1.RightEdge,  rect2)
proc isRectOverRect*[T:PRect](rect1, rect2: T): bool =
  # Check if rect1 completely covers rect2
  # TODO: Use <=, >= instead of <, > ?
  rect1.TopEdge    < rect2.TopEdge    and
  rect1.LeftEdge   < rect2.LeftEdge   and
  rect1.BottomEdge > rect2.BottomEdge and
  rect1.RightEdge  > rect2.RightEdge


# Misc Procs
proc randRect*(id: RectID, panelSize: Size, log: bool=false): Rect = 
  var rw: int
  var rh: int
  let rectPosX:  int = rand(panelSize.w  - rw  - 1)
  let rectPosY:  int = rand(panelSize.h - rh - 1)

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
  result = rects.Rect( x: rectPosX,
                       y: rectPosY,
                       w: rw div 2,
                       h: rh div 2,
                       id: id, 
                       label: "whatevs",
                       origin: (10, 20),
                       rot: rand(Rotation),
                       selected: false,
                       penColor: penColor,
                       brushColor: brushColor)

proc moveRectBy*[T:SomeRect](rect: T, delta: Point) =
  rect.x += delta.x
  rect.y += delta.y

proc moveRectTo*[T:SomeRect](rect: T, pos: Point) = 
  rect.x = pos.x
  rect.y = pos.y

proc boundingBox*[T:SomeRect](rects: openArray[T]): PRect {.inline.} =
  var left, right, top, bottom: int
  left = int.high
  right = int.low
  top = int.high
  bottom = int.low
  for r in rects:
    left   = min(left,   r.LeftEdge.x)
    top    = min(top,    r.TopEdge.y)
    right  = max(right,  r.RightEdge.x)
    bottom = max(bottom, r.BottomEdge.y)
  (x: left, 
   y: top, 
   w: right - left, 
   h: bottom - top)

proc rotateSize*[T:PRect](rect: T, amt: Rotation): Size =
  # Return size of rect if rotated by amt.
  # When rect.typeof is Rect, ignore current rotation
  # Basically swap the width, height if amt is 90 or 270
  case amt
  of R0:   (rect.w,  rect.h)
  of R90:  (rect.h, rect.w )
  of R180: (rect.w,  rect.h)
  of R270: (rect.h, rect.w )

proc rotate*(rect: Rect, amt: Rotation) =
  rect.rot = rect.rot + amt

proc rotate*(rect: Rect, orient: Orientation) =
  if rect.w >= rect.h:
    if orient == Horizontal: rect.rot = R0
    else: rect.rot = R90
  else:
    if orient == Horizontal: rect.rot = R90
    else: rect.rot = R0
    

proc area*(rect: SomeRect): int {.inline.} =
  rect.w * rect.h

proc aspectRatio*(rect: SomeRect): float =
  when typeof(rect) is rects.Rect:
    if rect.rot == R90 or rect.rot == R180:
      rect.w.float / rect.h.float
    else:
      rect.h.float / rect.w.float
  else:
    rect.w.float / rect.h.float

proc aspectRatio*[T:SomeRect](rects: seq[T]): float =
  rects.boundingBox.aspectRatio

proc fillArea*[T:SomeRect](rects: seq[T]): int =
  for r in rects:
    result += r.area

proc fillRatio*[T:SomeRect](rects: seq[T]): float =
  # Find ratio of total area to filled area
  rects.fillArea.float / rects.boundingBox.area.float

proc normalizeRectCoords*(startPos, endPos: Point): PRect =
  # make sure that rect.x,y is always upper left
  let (sx,sy) = startPos
  let (ex,ey) = endPos
  (x: min(sx, ex),
   y: min(sy, ey),
   w: abs(ex - sx),
   h: abs(ey - sy))

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

converter toSize*(size: wSize): Size =
  result.w = size.width
  result.h = size.height
converter toPoint*(pt: wPoint): Point {.inline.} =
  result.x = pt.x
  result.y = pt.y


proc testRots() =
  var rot: Rotation
  assert R0.toFloat == 0.0
  assert R90.toFloat == 90.0
  assert R180.toFloat == 180.0
  assert R270.toFloat == 270.0
  rot.inc; assert rot == R90
  rot.inc; assert rot == R180
  rot.inc; assert rot == R270
  rot.inc; assert rot == R0
  rot.dec; assert rot == R270
  rot.dec; assert rot == R180
  rot.dec; assert rot == R90
  rot.dec; assert rot == R0
  assert R0   + R0   == R0
  assert R0   + R90  == R90
  assert R0   + R180 == R180
  assert R0   + R270 == R270
  assert R90  + R0   == R90
  assert R90  + R90  == R180
  assert R90  + R180 == R270
  assert R90  + R270 == R0
  assert R180 + R0   == R180
  assert R180 + R90  == R270
  assert R180 + R180 == R0
  assert R180 + R270 == R90
  assert R270 + R0   == R270
  assert R270 + R90  == R0
  assert R270 + R180 == R90
  assert R270 + R270 == R180
  assert R90  + R0   == R90
  assert R180 + R0   == R180
  assert R270 + R0   == R270
  assert R0   + R90  == R90
  assert R90  + R90  == R180
  assert R180 + R90  == R270
  assert R270 + R90  == R0
  assert R0   + R180 == R180
  assert R90  + R180 == R270
  assert R180 + R180 == R0
  assert R270 + R180 == R90
  assert R0   + R270 == R270
  assert R90  + R270 == R0
  assert R180 + R270 == R90
  assert R270 + R270 == R180
proc testRectsRects() =
  var
    r1 = Rect(x:10, y:20, w:50, h:60, origin: (10, 10),            id: 3.RectID)
    r2 = Rect(x:10, y:20, w:50, h:60, origin: (10, 10), rot: R90,  id: 5.RectID)
    r3 = Rect(x:10, y:20, w:50, h:60, origin: (10, 10), rot: R180, id: 7.RectID)
    r4 = Rect(x:10, y:20, w:50, h:60, origin: (10, 10), rot: R270, id: 11.RectID)
    fourRects    = [r1, r2, r3, r4]
    lefts        = [  0,   0, -30, -40]
    rights       = [ 50,  60,  20,  20]
    tops         = [ 10, -20, -30,  10]
    bottoms      = [ 70,  30,  30,  60]
    outerLefts   = [ -1,  -1, -31, -41]
    outerRights  = [ 51,  61,  21,  21]
    outerTops    = [  9, -21, -31,   9]
    outerBottoms = [ 71,  31,  31,  61]
    r1l  = lefts[0]
    r1r  = rights[0]
    r1t  = tops[0]
    r1b  = bottoms[0]
    r1ol = outerLefts[0]
    r1or = outerRights[0]
    r1ot = outerTops[0]
    r1ob = outerBottoms[0]
    
    r2l  = lefts[1]
    r2r  = rights[1]
    r2t  = tops[1]
    r2b  = bottoms[1]
    r2ol = outerLefts[1]
    r2or = outerRights[1]
    r2ot = outerTops[1]
    r2ob = outerBottoms[1]
    
    r3l  = lefts[2]
    r3r  = rights[2]
    r3t  = tops[2]
    r3b  = bottoms[2]
    r3ol = outerLefts[2]
    r3or = outerRights[2]
    r3ot = outerTops[2]
    r3ob = outerBottoms[2]
    
    r4l =  lefts[3]
    r4r =  rights[3]
    r4t =  tops[3]
    r4b =  bottoms[3]
    r4ol = outerLefts[3]
    r4or = outerRights[3]
    r4ot = outerTops[3]
    r4ob = outerBottoms[3]
    
    r1p1  = (r1l,  r1t)
    r1p2  = (r1r,  r1t)
    r1p3  = (r1l,  r1b)
    r1p4  = (r1r,  r1b)
    r1op1 = (r1ol, r1ot)
    r1op2 = (r1or, r1ot)
    r1op3 = (r1ol, r1ob)
    r1op4 = (r1or, r1ob)
    r1te =     TopEdge(pt0: r1p1, pt1: r1p2)
    r1be =  BottomEdge(pt0: r1p3, pt1: r1p4)
    r1le =    LeftEdge(pt0: r1p1, pt1: r1p3)
    r1re =   RightEdge(pt0: r1p2, pt1: r1p4)
    r1ote =    TopEdge(pt0: r1op1, pt1: r1op2)
    r1obe = BottomEdge(pt0: r1op3, pt1: r1op4)
    r1ole =   LeftEdge(pt0: r1op1, pt1: r1op3)
    r1ore =  RightEdge(pt0: r1op2, pt1: r1op4)

    r1Outer = Rect(x: 10, y: 20, w: 52, h:62, origin: (11,11), rot: R0,   id: 13.RectID)
    r2Outer = Rect(x: 10, y: 20, w: 52, h:62, origin: (11,11), rot: R90,  id: 15.RectID)
    r3Outer = Rect(x: 10, y: 20, w: 52, h:62, origin: (11,11), rot: R180, id: 17.RectID)
    r4Outer = Rect(x: 10, y: 20, w: 52, h:62, origin: (11,11), rot: R270, id: 19.RectID)
  
    r2p1  = (r2l,  r2t)
    r2p2  = (r2r,  r2t)
    r2p3  = (r2l,  r2b)
    r2p4  = (r2r,  r2b)
    r2op1 = (r2ol, r2ot)
    r2op2 = (r2or, r2ot)
    r2op3 = (r2ol, r2ob)
    r2op4 = (r2or, r2ob)
    r2te =     TopEdge(pt0: r2p1,  pt1: r2p2)
    r2be =  BottomEdge(pt0: r2p3,  pt1: r2p4)
    r2le =    LeftEdge(pt0: r2p1,  pt1: r2p3)
    r2re =   RightEdge(pt0: r2p2,  pt1: r2p4)
    r2ote =    TopEdge(pt0: r2op1, pt1: r2op2)
    r2obe = BottomEdge(pt0: r2op3, pt1: r2op4)
    r2ole =   LeftEdge(pt0: r2op1, pt1: r2op3)
    r2ore =  RightEdge(pt0: r2op2, pt1: r2op4)
  
    r3p1  = (r3l,  r3t)
    r3p2  = (r3r,  r3t)
    r3p3  = (r3l,  r3b)
    r3p4  = (r3r,  r3b)
    r3op1 = (r3ol, r3ot)
    r3op2 = (r3or, r3ot)
    r3op3 = (r3ol, r3ob)
    r3op4 = (r3or, r3ob)
    r3te =     TopEdge(pt0: r3p1,  pt1: r3p2)
    r3be =  BottomEdge(pt0: r3p3,  pt1: r3p4)
    r3le =    LeftEdge(pt0: r3p1,  pt1: r3p3)
    r3re =   RightEdge(pt0: r3p2,  pt1: r3p4)
    r3ote =    TopEdge(pt0: r3op1, pt1: r3op2)
    r3obe = BottomEdge(pt0: r3op3, pt1: r3op4)
    r3ole =   LeftEdge(pt0: r3op1, pt1: r3op3)
    r3ore =  RightEdge(pt0: r3op2, pt1: r3op4)
  
    r4p1  = (r4l,  r4t)
    r4p2  = (r4r,  r4t)
    r4p3  = (r4l,  r4b)
    r4p4  = (r4r,  r4b)
    r4op1 = (r4ol, r4ot)
    r4op2 = (r4or, r4ot)
    r4op3 = (r4ol, r4ob)
    r4op4 = (r4or, r4ob)
    r4te =     TopEdge(pt0: r4p1,  pt1: r4p2)
    r4be =  BottomEdge(pt0: r4p3,  pt1: r4p4)
    r4le =    LeftEdge(pt0: r4p1,  pt1: r4p3)
    r4re =   RightEdge(pt0: r4p2,  pt1: r4p4)
    r4ote =    TopEdge(pt0: r4op1, pt1: r4op2)
    r4obe = BottomEdge(pt0: r4op3, pt1: r4op4)
    r4ole =   LeftEdge(pt0: r4op1, pt1: r4op3)
    r4ore =  RightEdge(pt0: r4op2, pt1: r4op4)
  

  assert r1.pos  == (10, 20)
  assert r2.pos  == (10, 20)
  assert r3.pos  == (10, 20)
  assert r4.pos  == (10, 20)
  assert r1.size == (50, 60)
  assert r2.size == (60, 50)
  assert r3.size == (50, 60)
  assert r4.size == (60, 50)
  assert r1.toRectNoRot == (  0.cint,  10.cint, 50.cint, 60.cint)
  assert r2.toRectNoRot == (  0.cint,  10.cint, 50.cint, 60.cint)
  assert r3.toRectNoRot == (  0.cint,  10.cint, 50.cint, 60.cint)
  assert r4.toRectNoRot == (  0.cint,  10.cint, 50.cint, 60.cint)
  assert r1.toRect      == (  0.cint,  10.cint, 50.cint, 60.cint)
  assert r2.toRect      == (  0.cint, -20.cint, 60.cint, 50.cint)
  assert r3.toRect      == (-30.cint, -30.cint, 50.cint, 60.cint)
  assert r4.toRect      == (-40.cint,  10.cint, 60.cint, 50.cint)
  assert r1.originXLeft == 10
  assert r2.originXLeft == 10
  assert r3.originXLeft == 40
  assert r4.originXLeft == 50
  assert r1.originYUp   == 10
  assert r2.originYUp   == 40
  assert r3.originYUp   == 50
  assert r4.originYUp   == 10
  assert r1.upperLeft  == (  0,  10)
  assert r1.upperRight == ( 50,  10)
  assert r1.lowerLeft  == (  0,  70)
  assert r1.lowerRight == ( 50,  70)
  assert r2.upperLeft  == (  0, -20)
  assert r2.upperRight == ( 60, -20)
  assert r2.lowerLeft  == (  0,  30)
  assert r2.lowerRight == ( 60,  30)
  assert r3.upperLeft  == (-30, -30)
  assert r3.upperRight == ( 20, -30)
  assert r3.lowerLeft  == (-30,  30)
  assert r3.lowerRight == ( 20,  30)
  assert r4.upperLeft  == (-40,  10)
  assert r4.upperRight == ( 20,  10)
  assert r4.lowerLeft  == (-40,  60)
  assert r4.lowerRight == ( 20,  60)
  assert r1.TopEdge    ==    TopEdge(pt0: (  0,  10), pt1: ( 50,  10))
  assert r1.BottomEdge == BottomEdge(pt0: (  0,  70), pt1: ( 50,  70))
  assert r1.LeftEdge   ==   LeftEdge(pt0: (  0,  10), pt1: (  0,  70))
  assert r1.RightEdge  ==  RightEdge(pt0: ( 50,  10), pt1: ( 50,  70))
  assert r2.TopEdge    ==    TopEdge(pt0: (  0, -20), pt1: ( 60, -20))
  assert r2.BottomEdge == BottomEdge(pt0: (  0,  30), pt1: ( 60,  30))
  assert r2.LeftEdge   ==   LeftEdge(pt0: (  0, -20), pt1: (  0,  30))
  assert r2.RightEdge  ==  RightEdge(pt0: ( 60, -20), pt1: ( 60,  30))
  assert r3.TopEdge    ==    TopEdge(pt0: (-30,- 30), pt1: ( 20, -30))
  assert r3.BottomEdge == BottomEdge(pt0: (-30,  30), pt1: ( 20,  30))
  assert r3.LeftEdge   ==   LeftEdge(pt0: (-30, -30), pt1: (-30,  30))
  assert r3.RightEdge  ==  RightEdge(pt0: ( 20, -30), pt1: ( 20,  30))
  assert r4.TopEdge    ==    TopEdge(pt0: (-40,  10), pt1: ( 20,  10))
  assert r4.BottomEdge == BottomEdge(pt0: (-40,  60), pt1: ( 20,  60))
  assert r4.LeftEdge   ==   LeftEdge(pt0: (-40,  10), pt1: (-40,  60))
  assert r4.RightEdge  ==  RightEdge(pt0: ( 20,  10), pt1: ( 20,  60))
  assert r1te          == r1.TopEdge
  assert r1be          == r1.BottomEdge
  assert r1le          == r1.LeftEdge
  assert r1re          == r1.RightEdge
  assert r2te          == r2.TopEdge
  assert r2be          == r2.BottomEdge
  assert r2le          == r2.LeftEdge
  assert r2re          == r2.RightEdge
  assert r3te          == r3.TopEdge
  assert r3be          == r3.BottomEdge
  assert r3le          == r3.LeftEdge
  assert r3re          == r3.RightEdge
  assert r4te          == r4.TopEdge
  assert r4be          == r4.BottomEdge
  assert r4le          == r4.LeftEdge
  assert r4re          == r4.RightEdge
  assert r1.LeftEdge.x   ==   0
  assert r1.RightEdge.x  ==  50
  assert r1.TopEdge.y    ==  10
  assert r1.BottomEdge.y ==  70
  assert r2.LeftEdge.x   ==   0
  assert r2.RightEdge.x  ==  60
  assert r2.TopEdge.y    == -20
  assert r2.BottomEdge.y ==  30
  assert r3.LeftEdge.x   == -30
  assert r3.RightEdge.x  ==  20
  assert r3.TopEdge.y    == -30
  assert r3.BottomEdge.y ==  30
  assert fourRects.ids == [3.RectID, 5.RectID, 7.RectID, 11.RectID]
  assert r1.LeftEdge < r1.RightEdge
  assert r2.LeftEdge < r2.RightEdge
  assert r3.LeftEdge < r3.RightEdge
  assert r4.LeftEdge < r4.RightEdge
  assert r1.TopEdge  < r1.BottomEdge
  assert r2.TopEdge  < r2.BottomEdge
  assert r3.TopEdge  < r3.BottomEdge
  assert r4.TopEdge  < r4.BottomEdge

  assert     isPointInRect(r1.upperLeft,  r1)
  assert     isPointInRect(r1.upperRight, r1)
  assert     isPointInRect(r1.lowerLeft,  r1)
  assert     isPointInRect(r1.lowerRight, r1)
  assert not isPointInRect(( -1,  10), r1)
  assert not isPointInRect((  0,   9), r1)
  assert not isPointInRect(( 51,  10), r1)
  assert not isPointInRect(( 50,   9), r1)
  assert not isPointInRect(( -1,  70), r1)
  assert not isPointInRect((  0,  71), r1)
  assert not isPointInRect(( 51,  70), r1)
  assert not isPointInRect(( 50,  71), r1)
  
  assert     isPointInRect(r2.upperLeft,  r2)
  assert     isPointInRect(r2.upperRight, r2)
  assert     isPointInRect(r2.lowerLeft,  r2)
  assert     isPointInRect(r2.lowerRight, r2)
  assert not isPointInRect(( -1, -20), r2)
  assert not isPointInRect((  0, -21), r2)
  assert not isPointInRect(( 61, -20), r2)
  assert not isPointInRect(( 60, -21), r2)
  assert not isPointInRect(( -1,  30), r2)
  assert not isPointInRect((  0,  31), r2)
  assert not isPointInRect(( 61,  30), r2)
  assert not isPointInRect(( 60,  31), r2)

  assert     isPointInRect(r3.upperLeft,  r3)
  assert     isPointInRect(r3.upperRight, r3)
  assert     isPointInRect(r3.lowerLeft,  r3)
  assert     isPointInRect(r3.lowerRight, r3)
  assert not isPointInRect((-31, -30), r3)
  assert not isPointInRect((-30, -31), r3)
  assert not isPointInRect(( 21, -30), r3)
  assert not isPointInRect(( 20, -31), r3)
  assert not isPointInRect((-31,  30), r3)
  assert not isPointInRect((-30,  31), r3)
  assert not isPointInRect(( 21,  30), r3)
  assert not isPointInRect(( 20,  31), r3)
  
  assert     isPointInRect(r4.upperLeft,  r4)
  assert     isPointInRect(r4.upperRight, r4)
  assert     isPointInRect(r4.lowerLeft,  r4)
  assert     isPointInRect(r4.lowerRight, r4)
  assert not isPointInRect((-41,  10), r4)
  assert not isPointInRect((-40,   9), r4)
  assert not isPointInRect(( 21,  10), r4)
  assert not isPointInRect(( 20,   9), r4)
  assert not isPointInRect((-41,  60), r4)
  assert not isPointInRect((-40,  61), r4)
  assert not isPointInRect(( 21,  60), r4)
  assert not isPointInRect(( 20,  61), r4)

  assert     isEdgeInRect(r1.LeftEdge,   r1)
  assert     isEdgeInRect(r1.RightEdge,  r1)
  assert     isEdgeInRect(r1.TopEdge,    r1)
  assert     isEdgeInRect(r1.BottomEdge, r1)

  assert     isEdgeInRect(r2.LeftEdge,   r2)
  assert     isEdgeInRect(r2.RightEdge,  r2)
  assert     isEdgeInRect(r2.TopEdge,    r2)
  assert     isEdgeInRect(r2.BottomEdge, r2)

  assert     isEdgeInRect(r3.LeftEdge,   r3)
  assert     isEdgeInRect(r3.RightEdge,  r3)
  assert     isEdgeInRect(r3.TopEdge,    r3)
  assert     isEdgeInRect(r3.BottomEdge, r3)

  assert     isEdgeInRect(r4.LeftEdge,   r4)
  assert     isEdgeInRect(r4.RightEdge,  r4)
  assert     isEdgeInRect(r4.TopEdge,    r4)
  assert     isEdgeInRect(r4.BottomEdge, r4)

  assert not isEdgeInRect(r1ote, r1)
  assert not isEdgeInRect(r1obe, r1)
  assert not isEdgeInRect(r1ole, r1)
  assert not isEdgeInRect(r1ore, r1)

  assert not isEdgeInRect(r2ote, r2)
  assert not isEdgeInRect(r2obe, r2)
  assert not isEdgeInRect(r2ole, r2)
  assert not isEdgeInRect(r2ore, r2)

  assert not isEdgeInRect(r3ote, r3)
  assert not isEdgeInRect(r3obe, r3)
  assert not isEdgeInRect(r3ole, r3)
  assert not isEdgeInRect(r3ore, r3)

  assert not isEdgeInRect(r4ote, r4)
  assert not isEdgeInRect(r4obe, r4)
  assert not isEdgeInRect(r4ole, r4)
  assert not isEdgeInRect(r4ore, r4)

  
  assert     isRectOverRect(r1Outer, r1)
  assert not isRectOverRect(r2Outer, r1)
  assert not isRectOverRect(r3Outer, r1)
  assert not isRectOverRect(r4Outer, r1)

  assert not isRectOverRect(r1Outer, r2)
  assert     isRectOverRect(r2Outer, r2)
  assert not isRectOverRect(r3Outer, r2)
  assert not isRectOverRect(r4Outer, r2)

  assert not isRectOverRect(r1Outer, r3)
  assert not isRectOverRect(r2Outer, r3)
  assert     isRectOverRect(r3Outer, r3)
  assert not isRectOverRect(r4Outer, r3)

  assert not isRectOverRect(r1Outer, r4)
  assert not isRectOverRect(r2Outer, r4)
  assert not isRectOverRect(r3Outer, r4)
  assert     isRectOverRect(r4Outer, r4)

  moveRectBy(r1, (5,6))
  moveRectBy(r2, (5,6))
  moveRectBy(r3, (5,6))
  moveRectBy(r4, (5,6))
  assert r1 == Rect(x:15, y:26, w:50, h:60, origin: (10,10))
  assert r2 == Rect(x:15, y:26, w:50, h:60, origin: (10,10), rot: R90)
  assert r3 == Rect(x:15, y:26, w:50, h:60, origin: (10,10), rot: R180)
  assert r4 == Rect(x:15, y:26, w:50, h:60, origin: (10,10), rot: R270)

  moveRectTo(r1, (2,3))
  moveRectTo(r2, (2,3))
  moveRectTo(r3, (2,3))
  moveRectTo(r4, (2,3))
  assert r1 == Rect(x:2, y:3, w:50, h:60, origin: (10,10))
  assert r2 == Rect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R90)
  assert r3 == Rect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R180)
  assert r4 == Rect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R270)

  assert boundingBox([r1]) == (x:r1.left.cint, y:r1.top.cint, w:r1.w.cint, h:r1.h.cint)
  assert boundingBox([r2]) == (x:r2.left.cint, y:r2.top.cint, w:r2.h.cint, h:r2.w.cint)
  assert boundingBox([r3]) == (x:r3.left.cint, y:r3.top.cint, w:r3.w.cint, h:r3.h.cint)
  assert boundingBox([r4]) == (x:r4.left.cint, y:r4.top.cint, w:r4.h.cint, h:r4.w.cint)

when isMainModule:
  testRots()
  testRectsRects()


