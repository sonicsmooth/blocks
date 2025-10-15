import std/[math, options, random, sets, sequtils, strutils, tables, ]
import wNim/wTypes
import wNim/private/wHelper
import randrect
import colors
import world, viewport
export world, viewport

# Generally,
#  DBComp is a domain rectangle in the database
#  DBComp does not consider pixels
#  Corners, edges, points, etc. are ideal and refer to edges

#  PRect is a graphical literal rectangle
#  Corners, edges, points, etc., refer to pixels and their indices

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
    └─┴─┴─┘ 
]#


#[
DBComp has position of origin, origin offset, width, height
WRect has pos of lowerLeft, width, height
PRect has pos of upperLeft, width, height
For filling texture cache and blitting we need unrotated PRect from DBComp
Then blit and rotate around origin
For bounds we need rotated WRect from DBComp
]#


type 
  CompID* = uint
  Rotation* = enum R0, R90, R180, R270
  Orientation* = enum Vertical, Horizontal
  PRect* = tuple[x, y, w, h: PxType]  # screen/pixel rectangle
  WRect* = tuple[x, y, w, h: WType ]  # world rectangle
  SomeRect = PRect | WRect
  
  Edge*[T] = object of RootObj
    when T is WRect:
      pt0*: WPoint
      pt1*: WPoint
    elif T is PRect:
      pt0*: PxPoint
      pt1*: PxPoint

  VertEdge*[T]   = object of Edge[T]
  HorizEdge*[T]  = object of Edge[T]
  LeftEdge*[T]   = object of VertEdge[T]
  RightEdge*[T]  = object of VertEdge[T]
  TopEdge*[T]    = object of HorizEdge[T]
  BottomEdge*[T] = object of HorizEdge[T]

  DBComp* = ref object # database object to be replaced later by Component, etc.
    x*: WType
    y*: WType
    w*: WType
    h*: WType
    id*: CompID
    label*: string
    origin*: WPoint
    rot*: Rotation
    penColor*: ColorU32
    fillColor*: ColorU32
    hoverColor*: ColorU32
    selected*: bool
    hovering*: bool
    mBbox*: Wrect

const
  scale = 10
  WRANGE* = (5*scale) .. (25*scale)
  HRANGE* = (5*scale) .. (25*scale)
  wcdf = makecdf(WRANGE.len, 100.0, 0.1)
  hcdf = makecdf(HRANGE.len, 100.0, 0.1)

# Declarations
proc boundingBox*(rects: openArray[SomeRect]): WRect

# Procs for Rotation
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
    of R0: R0
    of R90: R270
    of R180: R180
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

# Procs for Component
proc `$`*(rect: DBComp): string =
  var strs: seq[string]
  for k, val in rect[].fieldPairs:
    strs.add(k & ": " & $val)
  result = strs.join(", ")
# proc `x`*(comp: DBComp): WType = 
#   echo "x getter"
#   comp.x
# proc `x=`*(comp: var DBComp, val: WType) = 
#   echo "x setter"
#   comp.x = val
# proc `y`*(comp: DBComp): WType = comp.y
# proc `y=`*(comp: var DBComp, val: WType) = comp.y = val
# proc `w`*(comp: DBComp): WType = comp.w
# proc `w=`*(comp: var DBComp, val: WType) = comp.w = val
# proc `h`*(comp: DBComp): WType = comp.h
# proc `h=`*(comp: var DBComp, val: WType) = comp.h = val
proc `==`*(a, b: DBComp): bool =
  # Don't include id, just position, size and rotation
  a.x == b.x and
  a.y == b.y and
  a.w == b.w and
  a.h == b.h and
  a.origin == b.origin and
  a.rot == b.rot
proc pos*(comp: DBComp): WPoint = (comp.x, comp.y)
# proc invalidateBbox*(comp: DBComp) = 
#   comp.mBbox = (0,0,0,0)
proc bbox*(rect: DBComp, rot: bool=true): WRect  =
  # Conversion from DBComp to WRect.
  # This is basis of upper/lower/left/right/edge/bounding box functions
  # Looks at rotation, then returns barebones rectangle x,y,w,h with
  # lowerleft origin in world space.
  # TODO: Use rotation/translation matrix with shortcuts for 0/90/180/270
  # TODO: cache or memoize WRect either in DBComp or in some other table
  let
    (w, h)   = (rect.w, rect.h)
    (x, y)   = (rect.x, rect.y)
    (ox, oy) = (rect.origin.x, rect.origin.y)
  var outx, outy, outw, outh: WType
  if rect.rot == R0 or rot == false:
    outx = x - ox
    outy = y - oy
    outw = w
    outh = h
  elif rect.rot == R90:
    outx = x + oy - h
    outy = y - ox
    outw = h
    outh = w
  elif rect.rot == R180:
    outx = x + ox - w
    outy = y + oy - h
    outw = w
    outh = h
  elif rect.rot == R270:
    outx = x - oy
    outy = y + ox - w
    outw = h
    outh = w
  rect.mBbox = (outx, outy, outw, outh)
  rect.mBbox
proc bboxes*[T:DBComp](rects: openArray[T]): seq[WRect] =
  for rect in rects:
    result.add(rect.bbox)
proc boundingBox*(rects: openArray[DBComp]): WRect  =
  rects.bboxes.boundingBox
proc originToLeftEdge*(rect: DBComp): WType =
  # Horizontal distance from left edge to origin after rotation
  case rect.rot:
  of R0:   rect.origin.x
  of R90:  rect.h - rect.origin.y
  of R180: rect.w - rect.origin.x
  of R270: rect.origin.y
proc originToRightEdge*(rect: DBComp): WType =
  # Horizontal distance from right edge to origin after rotation
  case rect.rot:
  of R0:   rect.w - rect.origin.x
  of R90:  rect.origin.y
  of R180: rect.origin.x
  of R270: rect.h - rect.origin.y
proc originToBottomEdge*(rect: DBComp): WType =
  # Vertical distance from bottom edge to origin after rotation
  case rect.rot:
  of R0:   rect.origin.y
  of R90:  rect.origin.x
  of R180: rect.h - rect.origin.y
  of R270: rect.w - rect.origin.x
proc originToTopEdge*(rect: DBComp): WType =
  # Vertical distance from top edge to origin after rotation
  case rect.rot:
  of R0 :  rect.h - rect.origin.y
  of R90:  rect.w - rect.origin.x
  of R180: rect.origin.y
  of R270: rect.origin.x
proc ids*(rects: openArray[DBComp]): seq[CompID] =
  # Get all CompIDs
  for rect in rects:
    result.add(rect.id)
proc moveRectBy*(rect: DBComp, delta: WPoint) =
  rect.x += delta.x
  rect.y += delta.y
proc moveRectTo*(rect: DBComp, pos: WPoint) = 
  rect.x = pos.x
  rect.y = pos.y
proc randRect*(id: CompID, region: WRect, log: bool=false): DBComp = 
  # Creat a DBComp with random position, size, color
  var rw: WType
  var rh: WType
  let rectPosX: WType = region.x + rand(region.w)
  let rectPosY: WType = region.y + rand(region.h)

  if log: # Make log distribution
    while true:
      rw = RND.sample(WRANGE.toSeq, wcdf)
      rh = RND.sample(HRANGE.toSeq, hcdf)
      if rw/rh >= (1/3) and rw/rh <= 3.0:
        break
  else: # Flat distribution
    rw = rand(WRANGE)
    rh = rand(HRANGE)

  let fillColor = randColor()
  let penColor   = fillColor * 0.25
  result = rects.DBComp( x: rectPosX,
                         y: rectPosY,
                         w: rw / 2,
                         h: rh / 2,
                         id: id, 
                         label: "whatevs",
                         origin: (10, 20),
                         rot: rand(Rotation),
                         selected: false,
                         hovering: false,
                         penColor: penColor,
                         fillColor: fillColor,
                         hoverColor: Yellow)
proc rotate*(rect: DBComp, amt: Rotation) =
  # Rotate by given amount.  Modifies rect.
  rect.rot = rect.rot + amt
proc rotate*(rect: DBComp, orient: Orientation) =
  # Rotate to either 0 or 90 based on aspect ratio and 
  # given orientation
  if rect.w >= rect.h:
    if orient == Horizontal: rect.rot = R0
    else: rect.rot = R90
  else:
    if orient == Horizontal: rect.rot = R90
    else: rect.rot = R0

# Procs for rects
proc pos*(rect: SomeRect): auto  = (x: rect.x, y: rect.y)
proc size*(rect: SomeRect): auto  = (w: rect.w, h: rect.h)
proc lowerLeft*(rect: SomeRect): auto =
  when SomeRect is WRect:
    (rect.x, rect.y).toWPoint
  elif SomeRect is PRect:
    (rect.x, rect.y + rect.h - 1).toPxPoint
proc lowerRight*(rect: SomeRect): auto = 
  when SomeRect is WRect:
    (rect.x + rect.w, rect.y).toWPoint
  elif SomeRect is PRect:
    (rect.x + rect.w - 1, rect.y + rect.h - 1).toPxPoint
proc upperLeft*(rect: SomeRect): auto = 
  when SomeRect is WRect:
    (rect.x, rect.y + rect.h).toWPoint
  elif SomeRect is PRect:
    (rect.x, rect.y).toPxPoint
proc upperRight*(rect: SomeRect): auto = 
  when SomeRect is WRect:
    (rect.x + rect.w, rect.y + rect.h).toWPoint
  elif SomeRect is PRect:
    (rect.x + rect.w - 1, rect.y).toPxPoint
proc topEdge*[T: SomeRect](rect: T): TopEdge[T] =
  result.pt0 = rect.upperLeft
  result.pt1 = rect.upperRight
proc bottomEdge*[T: SomeRect](rect: T): BottomEdge[T] =
  result.pt0 = rect.lowerLeft
  result.pt1 = rect.lowerRight
proc leftEdge*[T: SomeRect](rect: T): LeftEdge[T] =
  when T is WRect:
    result.pt0 = rect.lowerLeft
    result.pt1 = rect.upperLeft
  elif T is PRect:
    result.pt0 = rect.upperLeft
    result.pt1 = rect.lowerLeft
proc rightEdge*[T: SomeRect](rect: T): RightEdge[T] =
  when T is WRect:
    result.pt0 = rect.lowerRight
    result.pt1 = rect.upperRight
  elif T is PRect:
    result.pt0 = rect.upperRight
    result.pt1 = rect.lowerRight
proc top*(rect: SomeRect): auto = rect.upperLeft.y
proc bottom*(rect: SomeRect): auto = rect.lowerLeft.y
proc left*(rect: SomeRect): auto = rect.lowerLeft.x
proc right*(rect: SomeRect): auto = rect.lowerRight.x
proc toWRect*(rect: PRect, vp: ViewPort): WRect =
  # Converts from screen/pixel space to world space
  # PRect has x,y in upper left, so choose lower left then convert
  when WType is SomeFloat:
    (x: rect.x.toWorldX(vp),
     y: (rect.y + rect.h).toWorldY(vp),
     w: (rect.w.float / vp.zoom).WType,
     h: (rect.h.float / vp.zoom).WType)
  elif WType is SomeInteger:
    (x: rect.x.toWorldX(vp),
     y: (rect.y + rect.h).toWorldY(vp),
     w: (rect.w.float / vp.zoom).round.WType,
     h: (rect.h.float / vp.zoom).round.WType)
proc toPRect*(rect: WRect, vp: ViewPort): PRect  = 
  # Output's origin is upper left of rectangle
  let
    origin = rect.upperLeft.toPixel(vp)
    width  = (rect.w.float * vp.zoom).round.cint
    height = (rect.h.float * vp.zoom).round.cint
  (origin.x, origin.y + 1, width, height)
proc zero*(rect: SomeRect): auto  =
  when SomeRect is WRect:
    (x: 0.WType, y: 0.WType, w: rect.w, h: rect.h)
  elif SomeRect is PRect:
    (x: 0.PxType, y: 0.PxType, w: rect.w, h: rect.h)
proc area*(rect: SomeRect): auto  =
  rect.w * rect.h
proc aspectRatio*(rect: SomeRect): float =
  rect.w.float / rect.h.float
proc greatestDim*(rect: SomeRect): WType  = max(rect.w, rect.h)
proc boundingBox*(rects: openArray[SomeRect]): WRect  =
  var left, right, top, bottom: WType
  left   = WType.high
  right  = WType.low
  top    = WType.low
  bottom = WType.high
  for r in rects:
    left   = min(left,   r.left)
    bottom = min(bottom, r.bottom)
    right  = max(right,  r.right)
    top    = max(top,    r.top)
  (x: left, 
   y: bottom, 
   w: right - left,
   h: top - bottom )
proc fillArea*(rects: openArray[SomeRect]): auto =
  # Total area of all rectangles.  Does not account for overlap.
  when SomeRect is WRect:
    var a: WType
  elif SomeRect is PRect:
    var a: PxType
  for r in rects:
    a += r.area
  result = a
proc fillRatio*(rects: openArray[SomeRect]): float =
  # Find ratio of total area to filled area. Does not account
  # for overlap, so value can be > 1.0.
  let numerator = rects.fillArea.float
  let bb = rects.boundingBox
  let a = bb.area
  let denom = a.float 
  numerator / denom 
proc grow*(rect: WRect, amt: WType): WRect  =
  (x: rect.x - amt, 
   y: rect.y - amt, 
   w: rect.w + amt * 2, 
   h: rect.h + amt * 2)
proc grow*(rect: PRect, amt: PxType): PRect  =
  (x: rect.x - amt,
   y: rect.y - amt,
   w: rect.w + amt * 2,
   h: rect.h + amt * 2)
proc normalizePRectCoords*(startPos, endPos: PxPoint): PRect =
  # make sure that rect.x,y is always minimum (upper left for PRect)
  let (sx, sy) = startPos
  let (ex, ey) = endPos
  (x: min(sx, ex),
   y: min(sy, ey),
   w: abs(ex - sx),
   h: abs(ey - sy))


# Procs for edges
proc x*[T](edge: VertEdge[T] ): auto = edge.pt0.x
proc y*[T](edge: HorizEdge[T]): auto = edge.pt0.y
proc `<`* [T](edge1, edge2: VertEdge[T]):  bool  = edge1.x <  edge2.x
proc `<=`*[T](edge1, edge2: VertEdge[T]):  bool  = edge1.x <= edge2.x
proc `>`* [T](edge1, edge2: VertEdge[T]):  bool  = edge1.x >  edge2.x
proc `>=`*[T](edge1, edge2: VertEdge[T]):  bool  = edge1.x >= edge2.x
proc `==`*[T](edge1, edge2: VertEdge[T]):  bool  = edge1.x == edge2.x
proc `<`* [T](edge1, edge2: HorizEdge[T]): bool  = edge1.y <  edge2.y
proc `<=`*[T](edge1, edge2: HorizEdge[T]): bool  = edge1.y <= edge2.y
proc `>`* [T](edge1, edge2: HorizEdge[T]): bool  = edge1.y >  edge2.y
proc `>=`*[T](edge1, edge2: HorizEdge[T]): bool  = edge1.y >= edge2.y
proc `==`*[T](edge1, edge2: HorizEdge[T]): bool  = edge1.y == edge2.y


# Procs for hit testing
proc isPointInRect*(pt: WPoint, rect: WRect): bool  = 
    pt.x >= rect.left   and pt.x <= rect.right and
    pt.y >= rect.bottom and pt.y <= rect.top
proc isPointInRect*(pt: PxPoint, rect: PRect): bool  = 
  pt.x >= rect.left and pt.x <= rect.right and
  pt.y >= rect.top  and pt.y <= rect.bottom
proc isEdgeInRect[T: SomeRect](edge: VertEdge[T], rect: T): bool  =
  # Return true if any part of edge is in rect
  when T is WRect:
    (isPointInRect(edge.pt0, rect) or isPointInRect(edge.pt1, rect)) or 
    (edge.pt0.y < rect.bottomEdge.y and 
     edge.pt1.y > rect.topEdge.y and 
     edge >= rect.leftEdge and 
     edge <= rect.rightEdge)
  elif T is PRect:
    (isPointInRect(edge.pt0, rect) or isPointInRect(edge.pt1, rect)) or 
    (edge.pt0.y < rect.topEdge.y and 
     edge.pt1.y > rect.bottomEdge.y and 
     edge >= rect.leftEdge and 
     edge <= rect.rightEdge)
proc isEdgeInRect[T: SomeRect](edge: HorizEdge[T], rect: T): bool  =
  # Return true if any part of edge is in rect
  when T is WRect:
    (isPointInRect(edge.pt0, rect) or isPointInRect(edge.pt1, rect)) or 
    (edge.pt0.x < rect.leftEdge.x and 
     edge.pt1.x > rect.rightEdge.x and 
     edge >= rect.bottomEdge and edge <= rect.topEdge)
  elif T is PRect:
    (isPointInRect(edge.pt0, rect) or isPointInRect(edge.pt1, rect)) or 
    (edge.pt0.x < rect.leftEdge.x and 
     edge.pt1.x > rect.rightEdge.x and 
     edge >= rect.topEdge and edge <= rect.bottomEdge)
proc isRectInRect*[T: SomeRect](rect1, rect2: T): bool = 
  # Check if any corners or edges of rect2 are within rect1
  # Generally rect1 is moving around and rect2 is part of the db
  isEdgeInRect(rect1.topEdge,    rect2) or
  isEdgeInRect(rect1.bottomEdge, rect2) or
  isEdgeInRect(rect1.leftEdge,   rect2) or
  isEdgeInRect(rect1.rightEdge,  rect2)
proc isRectOverRect*[T: SomeRect](rect1, rect2: T): bool =
  # Check if rect1 completely covers rect2,
  # ie, all rect1 edges are on or outside rect2 edges
  when T is WRect:
    rect1.topEdge    > rect2.topEdge    and
    rect1.bottomEdge < rect2.bottomEdge and
    rect1.leftEdge   < rect2.leftEdge   and
    rect1.rightEdge  > rect2.rightEdge
  elif T is PRect:
    rect1.topEdge    < rect2.topEdge    and
    rect1.bottomEdge > rect2.bottomEdge and
    rect1.leftEdge   < rect2.leftEdge   and
    rect1.rightEdge  > rect2.rightEdge

proc isRectSeparate*[T: SomeRect](rect1, rect2: T): bool =
  # Returns true if rect1 and rect2 do not have any overlap
  rect1.bottomEdge > rect2.topEdge or
  rect1.rightEdge  < rect2.leftEdge or
  rect1.topEdge    < rect2.bottomEdge or
  rect1.leftEdge   > rect2.rightEdge


converter toSize*(size: wSize): PxSize = (size.width, size.height)
converter toPxPoint*(pt: wPoint): PxPoint = (pt.x, pt.y)


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
  assert R0   - R0   == R0
  assert R0   - R90  == R270
  assert R0   - R180 == R180
  assert R0   - R270 == R90
  assert R90  - R0   == R90
  assert R90  - R90  == R0
  assert R90  - R180 == R270
  assert R90  - R270 == R180
  assert R180 - R0   == R180
  assert R180 - R90  == R90
  assert R180 - R180 == R0
  assert R180 - R270 == R270
  assert R270 - R0   == R270
  assert R270 - R90  == R180
  assert R270 - R180 == R90
  assert R270 - R270 == R0
  assert R90  - R0   == R90
  assert R180 - R0   == R180
  assert R270 - R0   == R270
  assert R0   - R90  == R270
  assert R90  - R90  == R0
  assert R180 - R90  == R90
  assert R270 - R90  == R180
  assert R0   - R180 == R180
  assert R90  - R180 == R270
  assert R180 - R180 == R0
  assert R270 - R180 == R90
  assert R0   - R270 == R90
  assert R90  - R270 == R180
  assert R180 - R270 == R270
  assert R270 - R270 == R0



proc testRectsRects() =
  discard


when isMainModule:
  testRots()
  testRectsRects()


