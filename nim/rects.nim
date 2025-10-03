import std/[math, random, sets, sequtils, strutils, tables, sugar]
import wNim/wTypes
import wNim/private/wHelper
#from sdl2 import Rect, Point
import randrect
import colors
import world, viewport
export world, viewport

# Generally,
#  DBRect is a domain rectangle in the database
#  DBRect does not consider pixels
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
DBRect has position of origin, origin offset, width, height
WRect has pos of lowerLeft, width, height
PRect has pos of upperLeft, width, height
For filling texture cache and blitting we need unrotated PRect from DBRect
Then blit and rotate around origin
For bounds we need rotated WRect from DBRect
]#


type 
  RectID* = uint
  Rotation* = enum R0, R90, R180, R270
  Orientation* = enum Vertical, Horizontal
  PRect* = tuple[x, y, w, h: PxType]  # screen/pixel rectangle
  WRect* = tuple[x, y, w, h: WType] # world rectangle
  DBRect* = ref object # database object to be replaced later by Component, etc.
    x*: WType
    y*: WType
    w*: WType
    h*: WType
    id*: RectID
    label*: string
    origin*: WPoint
    rot*: Rotation
    penColor*: ColorU32
    fillColor*: ColorU32
    selected*: bool
  SomeWRect = DBRect | WRect
  Edge* = object of RootObj
    pt0*: WPoint
    pt1*: WPoint
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
  wcdf = makecdf(WRANGE.len, 100.0, 0.1)
  hcdf = makecdf(HRANGE.len, 100.0, 0.1)
  

# Declarations
proc `$`*(rect: DBRect): string
proc `$`*(rect: PRect): string
proc `==`*(a, b: DBRect): bool
proc pos*(rect: SomeWRect): WPoint {.inline.}
proc pos*(rect: PRect): PxPoint {.inline.}
proc size*(rect: SomeWRect): WSize {.inline.}
proc size*(rect: PRect): PxSize {.inline.}
proc greatestDim*(rect: PRect): cint {.inline.}
proc greatestDim*(rect: SomeWRect): WType {.inline.}
proc toWRect*(rect: DBRect, rot: bool): WRect {.inline.}
converter toWRect*(rect: DBRect): WRect {.inline.}
proc toWRect*(rect: PRect, vp: ViewPort): WRect {.inline.}
proc toPRect*(rect: WRect, vp: ViewPort): PRect {.inline.}
proc toPRect*(rect: DBRect, vp: ViewPort, rot: bool): PRect {.inline.}
proc zero*[T:PRect|WRect](rect: T): T {.inline.}
proc originToLeftEdge*(rect: DBRect): WType
proc originToRightEdge*(rect: DBRect): WType
proc originToBottomEdge*(rect: DBRect): WType
proc originToTopEdge*(rect: DBRect): WType
proc lowerLeft*(rect: SomeWRect): WPoint
proc lowerRight*(rect: SomeWRect): WPoint
proc upperLeft*(rect: SomeWRect): WPoint
proc upperRight*(rect: SomeWRect): WPoint
converter toTopEdge*(rect: SomeWRect): TopEdge
converter toLeftEdge*(rect: SomeWRect): LeftEdge
converter toBottomEdge*(rect: SomeWRect): BottomEdge
converter toRightEdge*(rect: SomeWRect): RightEdge
proc left*(rect: SomeWRect): WType
proc right*(rect: SomeWRect): WType
proc top*(rect: SomeWRect): WType
proc bottom*(rect: SomeWRect): WType
proc x*(edge: VertEdge ): WType {.inline.}
proc y*(edge: HorizEdge): WType {.inline.}
proc ids*(rects: openArray[DBRect]): seq[RectID]
proc `<`* (edge1, edge2: VertEdge): bool {.inline.}
proc `<=`*(edge1, edge2: VertEdge): bool {.inline.}
proc `>`* (edge1, edge2: VertEdge): bool {.inline.}
proc `>=`*(edge1, edge2: VertEdge): bool {.inline.}
proc `==`*(edge1, edge2: VertEdge): bool {.inline.}
proc `<`* (edge1, edge2: HorizEdge): bool {.inline.}
proc `<=`*(edge1, edge2: HorizEdge): bool {.inline.}
proc `>`* (edge1, edge2: HorizEdge): bool {.inline.}
proc `>=`*(edge1, edge2: HorizEdge): bool {.inline.}
proc `==`*(edge1, edge2: HorizEdge): bool {.inline.}
proc isPointInRect*(pt: WPoint, rect: WRect): bool {.inline.}
proc isEdgeInRect(edge: VertEdge, rect: WRect): bool {.inline.}
proc isEdgeInRect(edge: HorizEdge, rect: WRect): bool {.inline.}
proc isRectInRect*(rect1, rect2: WRect): bool 
proc isRectOverRect*(rect1, rect2: WRect): bool
proc isRectSeparate*(rect1, rect2: WRect): bool
proc randRect*(id: RectID, region: WRect, log: bool=false): DBRect 
proc moveRectBy*(rect: SomeWRect, delta: WPoint)
proc moveRectTo*(rect: SomeWRect, pos: WPoint) 
proc boundingBox*(rects: openArray[SomeWRect]): WRect {.inline.}
proc rotate*(rect: DBRect, amt: Rotation)
proc rotate*(rect: DBRect, orient: Orientation)
proc area*(rect: SomeWRect): WType {.inline.}
proc aspectRatio*(rect: SomeWRect): float
proc aspectRatio*[T:SomeWRect](rects: openArray[T]): float
proc fillArea*[T:SomeWRect](rects: openArray[T]): WType
proc fillRatio*[T:SomeWRect](rects: openArray[T]): float
proc normalizeRectCoords*(startPos, endPos: PxPoint): PRect
proc grow*(rect: WRect, amt: WType): WRect {.inline.}
proc grow*(rect: PRect, amt: PxType): PRect {.inline.}
proc toFloat*(rot: Rotation): float {.inline.}
proc inc*(r: var Rotation) {.inline.}
proc dec*(r: var Rotation) {.inline.}
proc `+`*(r1, r2:Rotation): Rotation {.inline.}
proc `-`*(r1, r2:Rotation): Rotation {.inline.}
converter toPxPoint*(pt: wPoint): PxPoint {.inline.}


# Procs for single Rect
proc `$`*(rect: DBRect): string =
  var strs: seq[string]
  for k, val in rect[].fieldPairs:
    strs.add(k & ": " & $val)
  result = strs.join(", ")
proc `$`*(rect: PRect): string =
  var strs: seq[string]
  for k, val in rect.fieldPairs:
    strs.add(k & ": " & $val)
  result = strs.join(", ")
proc `==`*(a, b: DBRect): bool =
  # Don't include id, just position, size and rotation
  a.x == b.x and
  a.y == b.y and
  a.w == b.w and
  a.h == b.h and
  a.origin == b.origin and
  a.rot == b.rot
proc pos*(rect: SomeWRect): WPoint {.inline.} =
  # Returns DBRect's origin.
  # Returns WRect's upper left corner 
  (rect.x, rect.y)
proc pos*(rect: PRect): PxPoint {.inline.} =
  # Returns PRect's upper left corner 
  (rect.x, rect.y)
proc size*(rect: SomeWRect): WSize {.inline.} =
  # Returns width and height, accounting for rotation if DBRect
  when SomeWRect is rects.DBRect:
    if rect.rot == R0 or rect.rot == R180:
      (rect.w, rect.h)
    else:
      (rect.h, rect.w)
  elif typeof(rect) is WRect:
    (rect.w, rect.h)
proc size*(rect: PRect): PxSize {.inline.} =
  # Returns width and height of screen rectangle
  # This is pixel count
  (rect.w, rect.h)

proc greatestDim*(rect: PRect): cint {.inline.} =
  max(rect.w, rect.h)

proc greatestDim*(rect: SomeWRect): WType {.inline.} =
  max(rect.w, rect.h)

proc toWRect*(rect: DBRect, rot: bool): WRect {.inline.} =
  # Conversion from DBRect to WRect.
  # This is basis of upper/lower/left/right/edge/bounding box functions
  # Looks at rotation, then returns barebones rectangle x,y,w,h with
  # lowerleft origin in world space.
  # Values are clipped to WType high/low
  # TODO: Use rotation/translation matrix with shortcuts for 0/90/180/270
  # TODO: cache or memoize WRect either in DBRect or in some other table
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
    outx = x + oy - h # + 1
    outy = y - ox
    outw = h
    outh = w
  elif rect.rot == R180:
    outx = x + ox - w #+ 1
    outy = y + oy - h #+ 1
    outw = w
    outh = h
  elif rect.rot == R270:
    outx = x - oy
    outy = y + ox - w #+ 1
    outw = h
    outh = w
  (outx, outy, outw, outh)
converter toWRect*(rect: DBRect): WRect {.inline.} =
  # Implicit conversion from DBRect to WRect.
  rect.toWRect(true) # Call main fn with rotation explicitly enabled

proc toWRect*(rect: PRect, vp: ViewPort): WRect =
  # Converts from screen/pixel space to world space
  # PRect has x,y in upper left, so choose lower left then convert
  when WType is SomeFloat:
    (rect.x.toWorldX(vp),
    (rect.y + rect.h).toWorldY(vp),
    (rect.w.float / vp.zoom).WType,
    (rect.h.float / vp.zoom).WType)
  elif WType is SomeInteger:
    (rect.x.toWorldX(vp),
    (rect.y + rect.h).toWorldY(vp),
    (rect.w.float / vp.zoom).round.WType,
    (rect.h.float / vp.zoom).round.WType)

proc toPRect*(rect: WRect, vp: ViewPort): PRect {.inline.} = 
  # Output's origin is upper left of rectangle
  let
    origin = rect.upperLeft.toPixel(vp)
    width  = (rect.w.float * vp.zoom).round.cint
    height = (rect.h.float * vp.zoom).round.cint
  # Add + 1 adjustment for y
  (origin.x, origin.y + 1, width, height)

proc toPRect*(rect: DBRect, vp: ViewPort, rot: bool): PRect {.inline.} = 
  # Output's origin is upper left of rectangle
  # if rot is false, then upper left is plain.
  # if rot is true, then, upper left is based on rotation
  let
    wrect = rect.toWRect(rot)
    origin = wrect.upperLeft.toPixel(vp)
    width = (wrect.w.float * vp.zoom).round.cint
    height = (wrect.h.float * vp.zoom).round.cint
  # Add + 1 adjustment for y
  (origin.x, origin.y + 1, width, height)

proc zero*[T:PRect|WRect](rect: T): T {.inline.} =
  when T is PRect:
    (0.cint, 0.cint, rect.w, rect.h)
  else:
    (0.CoordT, 0.CoordT, rect.w, rect.h)

proc originToLeftEdge*(rect: DBRect): WType =
  # Horizontal distance from left edge to origin after rotation
  case rect.rot:
  of R0:   rect.origin.x
  of R90:  rect.h - rect.origin.y
  of R180: rect.w - rect.origin.x
  of R270: rect.origin.y
proc originToRightEdge*(rect: DBRect): WType =
  # Horizontal distance from right edge to origin after rotation
  case rect.rot:
  of R0:   rect.w - rect.origin.x
  of R90:  rect.origin.y
  of R180: rect.origin.x
  of R270: rect.h - rect.origin.y
proc originToBottomEdge*(rect: DBRect): WType =
  # Vertical distance from bottom edge to origin after rotation
  case rect.rot:
  of R0:   rect.origin.y
  of R90:  rect.origin.x
  of R180: rect.h - rect.origin.y
  of R270: rect.w - rect.origin.x
proc originToTopEdge*(rect: DBRect): WType =
  # Vertical distance from top edge to origin after rotation
  case rect.rot:
  of R0 :  rect.h - rect.origin.y
  of R90:  rect.w - rect.origin.x
  of R180: rect.origin.y
  of R270: rect.origin.x

# Procs for single WRect
proc lowerLeft*(rect: SomeWRect):  WPoint =
  # toWRect applies rotation by default
  # So if you want corner of unrotated DBRect, first
  # do dbrect.toWRect(false) then call this function
  when SomeWRect is DBRect:
    let rect = rect.toWRect
  (rect.x, rect.y)
proc lowerRight*(rect: SomeWRect): WPoint = 
  when SomeWRect is DBRect:
    let rect = rect.toWRect
  (rect.x + rect.w, rect.y)
proc upperLeft*(rect: SomeWRect):  WPoint = 
  when SomeWRect is DBRect:
    let rect = rect.toWRect
  (rect.x, rect.y + rect.h)
proc upperRight*(rect: SomeWRect): WPoint = 
  when rect is DBRect:
    let rect = rect.toWRect
  (rect.x + rect.w, rect.y + rect.h)
converter toTopEdge*(rect: SomeWRect): TopEdge =
  result.pt0 = rect.upperLeft
  result.pt1 = rect.upperRight
converter toLeftEdge*(rect: SomeWRect): LeftEdge =
  result.pt0 = rect.lowerLeft
  result.pt1 = rect.upperLeft
converter toBottomEdge*(rect: SomeWRect): BottomEdge =
  result.pt0 = rect.lowerLeft
  result.pt1 = rect.lowerRight
converter toRightEdge*(rect: SomeWRect): RightEdge =
  result.pt0 = rect.lowerRight
  result.pt1 = rect.upperRight
proc left*(rect: SomeWRect): WType =
  rect.LeftEdge.x
proc right*(rect: SomeWRect): WType =
  rect.RightEdge.x
proc top*(rect: SomeWRect): WType =
  rect.TopEdge.y
proc bottom*(rect: SomeWRect): WType =
  rect.BottomEdge.y
proc x*(edge: VertEdge ): WType {.inline.} = edge.pt0.x
proc y*(edge: HorizEdge): WType {.inline.} = edge.pt0.y


# Procs for multiple Rects
proc ids*(rects: openArray[DBRect]): seq[RectID] =
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


# Procs for hit testing operate on world WRects
proc isPointInRect*(pt: WPoint, rect: WRect): bool {.inline.} = 
    let urcorner = rect.upperRight
    pt.x >= rect.x and pt.x <= urcorner.x and
    pt.y >= rect.y and pt.y <= urcorner.y
proc isEdgeInRect(edge: VertEdge, rect: WRect): bool {.inline.} =
  let edgeInside = (edge >= rect.LeftEdge and edge <= rect.RightEdge)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.y < rect.BottomEdge.y
  let pt1Outside = edge.pt1.y > rect.TopEdge.y
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)
proc isEdgeInRect(edge: HorizEdge, rect: WRect): bool {.inline.} =
  let edgeInside = (edge >= rect.BottomEdge and edge <= rect.TopEdge)
  let pt0Inside = isPointInRect(edge.pt0, rect)
  let pt1Inside = isPointInRect(edge.pt1, rect)
  let pt0Outside = edge.pt0.x < rect.LeftEdge.x
  let pt1Outside = edge.pt1.x > rect.RightEdge.x
  (pt0Inside or pt1Inside) or 
  (pt0Outside and pt1Outside and edgeInside)
proc isRectInRect*(rect1, rect2: WRect): bool = 
  # Check if any corners or edges of rect2 are within rect1
  # Generally rect1 is moving around and rect2 is part of the db
  isEdgeInRect(rect1.TopEdge,    rect2) or
  isEdgeInRect(rect1.LeftEdge,   rect2) or
  isEdgeInRect(rect1.BottomEdge, rect2) or
  isEdgeInRect(rect1.RightEdge,  rect2)
proc isRectOverRect*(rect1, rect2: WRect): bool =
  # Check if rect1 completely covers rect2,
  # ie, all rect1 edges are on or outside rect2 edges
  rect1.TopEdge    >= rect2.TopEdge    and
  rect1.LeftEdge   <= rect2.LeftEdge   and
  rect1.BottomEdge <= rect2.BottomEdge and
  rect1.RightEdge  >= rect2.RightEdge
proc isRectSeparate*(rect1, rect2: WRect): bool =
  # Returns true if rect1 and rect2 do not have any overlap
  rect1.BottomEdge > rect2.TopEdge or
  rect1.RightEdge  < rect2.LeftEdge or
  rect1.TopEdge    < rect2.BottomEdge or
  rect1.LeftEdge   > rect2.RightEdge

# Misc Procs
proc `/`[T:SomeInteger](a, b: T): T = 
  echo "my own div"
  a div b
proc `/`[T:SomeFloat](a, b: T): T = a / b


proc randRect*(id: RectID, region: WRect, log: bool=false): DBRect = 
  # Creat a DBRect with random position, size, color
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

  let fillColor = randColor() #ColorU32 0x7f_ff_00_00 # half red
  let penColor   = fillColor.colordiv(2)
  result = rects.DBRect( x: rectPosX,
                         y: rectPosY,
                         w: rw / 2,
                         h: rh / 2,
                         id: id, 
                         label: "whatevs",
                         origin: (10, 20),
                         rot: rand(Rotation),
                         selected: false,
                         penColor: penColor,
                         fillColor: fillColor)
proc moveRectBy*(rect: SomeWRect, delta: WPoint) =
  rect.x += delta.x
  rect.y += delta.y
proc moveRectTo*(rect: SomeWRect, pos: WPoint) = 
  rect.x = pos.x
  rect.y = pos.y
proc boundingBox*(rects: openArray[SomeWRect]): WRect {.inline.} =
  var left, right, top, bottom: WType
  left   = WType.high
  right  = WType.low
  top    = WType.low
  bottom = WType.high
  # Todo: make proc edges() that returns all edges with only one conversion
  for r in rects:
    left   = min(left,   r.left)
    bottom = min(bottom, r.bottom)
    right  = max(right,  r.right)
    top    = max(top,    r.top)
  (x: left, 
   y: bottom, 
   w: right - left, #+ 1, 
   h: top - bottom ) #+ 1)
proc rotate*(rect: DBRect, amt: Rotation) =
  # Rotate by given amount.  Modifies rect.
  rect.rot = rect.rot + amt
proc rotate*(rect: DBRect, orient: Orientation) =
  # Rotate to either 0 or 90 based on aspect ratio and 
  # given orientation
  if rect.w >= rect.h:
    if orient == Horizontal: rect.rot = R0
    else: rect.rot = R90
  else:
    if orient == Horizontal: rect.rot = R90
    else: rect.rot = R0
proc area*(rect: SomeWRect): WType {.inline.} =
  rect.w * rect.h
proc aspectRatio*(rect: SomeWRect): float =
  when SomeWRect is DBRect:
    if rect.rot == R90 or rect.rot == R270:
      rect.h.float / rect.w.float
    else:
      rect.w.float / rect.h.float
  else:
    rect.w.float / rect.h.float
proc aspectRatio*[T:SomeWRect](rects: openArray[T]): float =
  rects.boundingBox.aspectRatio
proc fillArea*[T:SomeWRect](rects: openArray[T]): WType =
  # Total area of all rectangles.  Does not account for overlap.
  for r in rects:
    result += r.area
proc fillRatio*[T:SomeWRect](rects: openArray[T]): float =
  # Find ratio of total area to filled area. Does not account
  # for overlap, so value can be > 1.0.
  rects.fillArea.float / rects.boundingBox.area.float
proc normalizeRectCoords*(startPos, endPos: PxPoint): PRect =
  # make sure that rect.x,y is always lower left
  let (sx, sy) = startPos
  let (ex, ey) = endPos
  (x: min(sx, ex),
   y: min(sy, ey),
   w: abs(ex - sx),
   h: abs(ey - sy))
proc grow*(rect: WRect, amt: WType): WRect {.inline.} =
  (rect.x - amt, rect.y - amt, rect.w + 2*amt, rect.h + 2*amt)
proc grow*(rect: PRect, amt: PxType): PRect {.inline.} =
  (rect.x - amt, rect.y - amt, rect.w + 2*amt, rect.h + 2*amt)

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

converter toSize*(size: wSize): PxSize =
  (size.width, size.height)
converter toPxPoint*(pt: wPoint): PxPoint {.inline.} =
  (pt.x, pt.y)


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
  var
    r1 = DBRect(x:10, y:20, w:50, h:60, origin: (10, 10),            id: 3.RectID)
    r2 = DBRect(x:10, y:20, w:50, h:60, origin: (10, 10), rot: R90,  id: 5.RectID)
    r3 = DBRect(x:10, y:20, w:50, h:60, origin: (10, 10), rot: R180, id: 7.RectID)
    r4 = DBRect(x:10, y:20, w:50, h:60, origin: (10, 10), rot: R270, id: 11.RectID)
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

    r1Outer = DBRect(x: 10, y: 20, w: 52, h:62, origin: (11,11), rot: R0,   id: 13.RectID)
    r2Outer = DBRect(x: 10, y: 20, w: 52, h:62, origin: (11,11), rot: R90,  id: 15.RectID)
    r3Outer = DBRect(x: 10, y: 20, w: 52, h:62, origin: (11,11), rot: R180, id: 17.RectID)
    r4Outer = DBRect(x: 10, y: 20, w: 52, h:62, origin: (11,11), rot: R270, id: 19.RectID)
  
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
  assert r4.pos  == (10.WType, 20.WType)
  # Not sure why above doesn't require .WType but below does,
  # as both pos and size return tuple[WType, WType]
  assert r1.size == (50.WType, 60.WType)
  assert r2.size == (60.WType, 50.WType)
  assert r3.size == (50.WType, 60.WType)
  assert r4.size == (60.WType, 50.WType)
  # TODO: add test for int.high convert to cint.high, etc.
  # assert r1.toPlainWRect ==  (  0.WType,  0.WType, 50.WType, 60.WType)
  # assert r2.toPlainWRect ==  (  0.WType,  0.WType, 50.WType, 60.WType)
  # assert r3.toPlainWRect ==  (  0.WType,  0.WType, 50.WType, 60.WType)
  # assert r4.toPlainWRect ==  (  0.WType,  0.WType, 50.WType, 60.WType)
  # assert r1.originToLeftEdge == 10
  # assert r2.originToLeftEdge == 50
  # assert r3.originToLeftEdge == 40
  # assert r4.originToLeftEdge == 10
  # assert r1.originToBottomEdge   == 10
  # assert r2.originToBottomEdge   == 10
  # assert r3.originToBottomEdge   == 50
  # assert r4.originToBottomEdge   == 40
  
  assert r1.lowerLeft  == (  0,  10)
  assert r2.lowerLeft  == (-40,  10)
  assert r3.lowerLeft  == (-30, -30)
  assert r4.lowerLeft  == (  0, -20)
  
  assert r1.lowerRight == ( 50,  9)
  assert r2.lowerRight == ( 20,  10)
  assert r3.lowerRight == ( 20, -30)
  assert r4.lowerRight == ( 60, -20)
  
  assert r1.upperRight == ( 50,  70)
  assert r2.upperRight == ( 20,  60)
  assert r3.upperRight == ( 20,  30)
  assert r4.upperRight == ( 60,  30)
  
  assert r1.upperLeft  == (  0,  70)
  assert r2.upperLeft  == (-40,  60)
  assert r3.upperLeft  == (-30,  30)
  assert r4.upperLeft  == (  0,  30)

  assert r1.TopEdge    == TopEdge(pt0: (  0,  70), pt1: ( 50,  70))
  assert r2.TopEdge    == TopEdge(pt0: (-40,  60), pt1: ( 20,  60))
  assert r3.TopEdge    == TopEdge(pt0: (-30,  30), pt1: ( 20,  30))
  assert r4.TopEdge    == TopEdge(pt0: (  0,  30), pt1: ( 60,  30))

  assert r1.BottomEdge == BottomEdge(pt0: (  0,  10), pt1: ( 50,  10))
  assert r2.BottomEdge == BottomEdge(pt0: (-40,  10), pt1: ( 20,  10))
  assert r3.BottomEdge == BottomEdge(pt0: (-30,- 30), pt1: ( 20, -30))
  assert r4.BottomEdge == BottomEdge(pt0: (  0, -20), pt1: ( 60, -20))

  assert r1.LeftEdge   == LeftEdge(pt0: (  0,  10), pt1: (  0,  70))
  assert r2.LeftEdge   == LeftEdge(pt0: (-40,  10), pt1: (-40,  60))
  assert r3.LeftEdge   == LeftEdge(pt0: (-30, -30), pt1: (-30,  30))
  assert r4.LeftEdge   == LeftEdge(pt0: (  0, -20), pt1: (  0,  30))

  assert r1.RightEdge  ==  RightEdge(pt0: ( 50,  10), pt1: ( 50,  70))
  assert r2.RightEdge  ==  RightEdge(pt0: ( 20,  10), pt1: ( 20,  60))
  assert r3.RightEdge  ==  RightEdge(pt0: ( 20, -30), pt1: ( 20,  30))
  assert r4.RightEdge  ==  RightEdge(pt0: ( 60, -20), pt1: ( 60,  30))

  assert r1.LeftEdge.x   ==   0
  assert r2.LeftEdge.x   == -40
  assert r3.LeftEdge.x   == -30
  assert r4.LeftEdge.x   ==   0
  
  assert r1.RightEdge.x  ==  50
  assert r2.RightEdge.x  ==  20
  assert r3.RightEdge.x  ==  20
  assert r4.RightEdge.x  ==  60

  assert r1.TopEdge.y    ==  70
  assert r2.TopEdge.y    ==  60
  assert r3.TopEdge.y    ==  30
  assert r4.TopEdge.y    ==  30

  assert r1.BottomEdge.y ==  10
  assert r2.BottomEdge.y ==  10
  assert r3.BottomEdge.y == -30
  assert r4.BottomEdge.y == -20
 
  
  
  assert fourRects.ids == [3.RectID, 5.RectID, 7.RectID, 11.RectID]
  assert r1.LeftEdge < r1.RightEdge
  assert r2.LeftEdge < r2.RightEdge
  assert r3.LeftEdge < r3.RightEdge
  assert r4.LeftEdge < r4.RightEdge

  assert r1.TopEdge  > r1.BottomEdge
  assert r2.TopEdge  > r2.BottomEdge
  assert r3.TopEdge  > r3.BottomEdge
  assert r4.TopEdge  > r4.BottomEdge

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
  assert r1 == DBRect(x:15, y:26, w:50, h:60, origin: (10,10))
  assert r2 == DBRect(x:15, y:26, w:50, h:60, origin: (10,10), rot: R90)
  assert r3 == DBRect(x:15, y:26, w:50, h:60, origin: (10,10), rot: R180)
  assert r4 == DBRect(x:15, y:26, w:50, h:60, origin: (10,10), rot: R270)

  moveRectTo(r1, (2,3))
  moveRectTo(r2, (2,3))
  moveRectTo(r3, (2,3))
  moveRectTo(r4, (2,3))
  assert r1 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10))
  assert r2 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R90)
  assert r3 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R180)
  assert r4 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R270)

  assert boundingBox([r1]) == (x:r1.left, y:r1.top, w:r1.w, h:r1.h)
  assert boundingBox([r2]) == (x:r2.left, y:r2.top, w:r2.h, h:r2.w)
  assert boundingBox([r3]) == (x:r3.left, y:r3.top, w:r3.w, h:r3.h)
  assert boundingBox([r4]) == (x:r4.left, y:r4.top, w:r4.h, h:r4.w)

  assert boundingBox([r1, r2]) == (x: -8.WType, 
                                   y: -37.WType,
                                   w: 60.WType,
                                   h: 90.WType)

  rotate(r1, R0);
  rotate(r2, R0);
  rotate(r3, R0);
  rotate(r4, R0);
  assert r1 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10))
  assert r2 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R90)
  assert r3 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R180)
  assert r4 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R270)

  rotate(r1, R90);
  rotate(r2, R90);
  rotate(r3, R90);
  rotate(r4, R90);
  assert r1 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R90)
  assert r2 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R180)
  assert r3 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R270)
  assert r4 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R0)

  rotate(r1, R180);
  rotate(r2, R180);
  rotate(r3, R180);
  rotate(r4, R180);
  assert r1 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R270)
  assert r2 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R0)
  assert r3 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R90)
  assert r4 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R180)

  rotate(r1, R270);
  rotate(r2, R270);
  rotate(r3, R270);
  rotate(r4, R270);
  assert r1 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R180)
  assert r2 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R270)
  assert r3 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R0)
  assert r4 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R90)

  rotate(r1, Horizontal);
  rotate(r2, Horizontal);
  rotate(r3, Horizontal);
  rotate(r4, Horizontal);
  assert r1 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R90)
  assert r2 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R90)
  assert r3 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R90)
  assert r4 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R90)

  rotate(r1, Vertical);
  rotate(r2, Vertical);
  rotate(r3, Vertical);
  rotate(r4, Vertical);
  assert r1 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R0)
  assert r2 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R0)
  assert r3 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R0)
  assert r4 == DBRect(x:2, y:3, w:50, h:60, origin: (10,10), rot: R0)

  assert area(r1) == 3000
  assert area(r2) == 3000
  assert area(r3) == 3000
  assert area(r4) == 3000

  r1 = DBRect(x:10, y:20, w:50, h:60, origin: (10, 10),            id: 3.RectID)
  r2 = DBRect(x:10, y:20, w:50, h:60, origin: (10, 10), rot: R90,  id: 5.RectID)
  r3 = DBRect(x:10, y:20, w:50, h:60, origin: (10, 10), rot: R180, id: 7.RectID)
  r4 = DBRect(x:10, y:20, w:50, h:60, origin: (10, 10), rot: R270, id: 11.RectID)

  assert aspectRatio(r1) == float(50) / float(60)
  assert aspectRatio(r2) == float(60) / float(50)
  assert aspectRatio(r3) == float(50) / float(60)
  assert aspectRatio(r4) == float(60) / float(50)

  assert fillArea([r1])             == 1 * (50 * 60)
  assert fillArea([r1, r2])         == 2 * (50 * 60)
  assert fillArea([r1, r2, r3])     == 3 * (50 * 60)
  assert fillArea([r1, r2, r3, r4]) == 4 * (50 * 60)

  assert fillRatio([r1])     == 1.0
  assert fillRatio([r1, r2]) == 2.0 * (50.0 * 60.0) / 5400.0

  assert normalizeRectCoords((10, 10), (50, 50)) == (x: 10.cint, y:10.cint, w: 40.cint, h: 40.cint)
  assert normalizeRectCoords((50, 50), (10, 10)) == (x: 10.cint, y:10.cint, w: 40.cint, h: 40.cint)

  var rr = DBRect(x: 0, y:0, w:5, h:5, origin: (2, 2), rot: R0)
  assert rr.rot == R0
  assert rr.originToLeftEdge == 2
  assert rr.originToRightEdge == 2
  assert rr.originToTopEdge == 2
  assert rr.originToBottomEdge == 2
  inc rr.rot
  assert rr.rot == R90
  assert rr.originToLeftEdge == 2
  assert rr.originToRightEdge == 2
  assert rr.originToTopEdge == 2
  assert rr.originToBottomEdge == 2
  inc rr.rot
  assert rr.rot == R180
  assert rr.originToLeftEdge == 2
  assert rr.originToRightEdge == 2
  assert rr.originToTopEdge == 2
  assert rr.originToBottomEdge == 2
  inc rr.rot
  assert rr.rot == R270
  assert rr.originToLeftEdge == 2
  assert rr.originToRightEdge == 2
  assert rr.originToTopEdge == 2
  assert rr.originToBottomEdge == 2



when isMainModule:
  testRots()
  testRectsRects()


