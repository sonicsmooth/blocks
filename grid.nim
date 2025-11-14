import std/[algorithm, math, sequtils]
import sdl2
import colors
from arange import arange
import viewport, pointmath
import appinit
import wNim/wTypes


type
  Scale* = enum None, Tiny, Minor, Major
  DotsOrLines* = enum Dots, Lines
  DivRange = range[2..16]
  # TODO: When these change they should trigger a refresh right away
  Grid* = ref object
    mMajorXSpace: WType
    mMajorYSpace: WType
    mDivisions:      DivRange
    mVisible*:       bool
    mOriginVisible*: bool
    mSnap*:          bool
    mDotsOrLines*: DotsOrLines = Lines
    mZctrl*:       ZoomCtrl

const
  alphaOffset = 20
  stepAlphas = arange(60 .. 255, alphaOffset).toSeq


proc majorXSpace*(grid: Grid): WType = grid.mMajorXSpace
proc majorYSpace*(grid: Grid): WType = grid.mMajorYSpace
proc `majorXSpace=`*(grid: Grid, val: WType) =
  grid.mMajorXSpace = val

proc `majorYSpace=`*(grid: Grid, val: WType) =
  grid.mMajorYSpace = val

proc allowedDivisions*(grid: Grid): seq[DivRange] =
  # Return list of allowable divisions, i.e., which
  # values in 2..16 divide major grid space evenly.
  # If the result for X and Y are different, then
  # return the intersection.  Typically the values
  # are 1,2,4,5,8,10,16.  1 will be treated as a
  # special case elsewhere
  var xset, yset: set[DivRange]
  for d in DivRange.low .. DivRange.high:
    if grid.mMajorXSpace mod d == 0: xset.incl(d)
    if grid.mMajorYSpace mod d == 0: yset.incl(d)
  (xset * yset).toSeq

proc allowedDivisionsStr*(grid: Grid): seq[string] =
  for d in grid.allowedDivisions:
    result.add($d)

proc divisions*(grid: Grid): int = grid.mDivisions

proc `divisions=`*(grid: var Grid, val: int): bool {.discardable.} =
  # Change grid's divisions to val
  # Clamps val to DivRange.
  # Returns true if given val is in allowed divisions, else false.

  let cval = clamp(val, DivRange.low, DivRange.high)
  if val != cval:
    echo val, " not in range! Setting to ", cval
    result = false
  else:
    result = cval in grid.allowedDivisions()

  if grid.mZctrl.baseSync:
    grid.mZctrl.base = cval
  grid.mDivisions = cval
 
proc divisionsIndex*(grid: Grid): int =
  grid.allowedDivisions.find(grid.mDivisions)

proc minDelta*(grid: Grid, scale: Scale): WPoint
proc areMinorDivisionsValid*(grid: Grid): bool =
  # True if minor grid spaces divide major grid spaces evenly
  # Generally this is false when divisions is weird or when 
  # zoomed in very far.
  grid.minDelta(scale=Major).x div grid.minDelta(scale=Minor).x == grid.mDivisions and
  grid.minDelta(scale=Major).y div grid.minDelta(scale=Minor).y == grid.mDivisions

proc areTinyDivisionsValid*(grid: Grid): bool =
  # True if minor grid spaces divide major grid spaces evenly
  # Generally this is false when divisions is weird or when 
  # zoomed in very far.
  grid.minDelta(scale=Minor).x div grid.minDelta(scale=Tiny).x == grid.mDivisions and
  grid.minDelta(scale=Minor).y div grid.minDelta(scale=Tiny).y == grid.mDivisions


proc minDelta*(grid: Grid, scale: Scale): WPoint =
  # Return minimum grid spacing.
  # Return type T i
  # When zoomed in far, stpScale is small and spacings are small.
  # When zoomed out, stpScale is large and spacings are large
  # scale lets you return different sizes
  let
    zc = grid.mZctrl
    stpScale: float = pow(zc.base.float, -zc.logStep.float)
    divs: float = grid.mDivisions.float

  when WType is SomeInteger:
    let
      # Tiny is independent
      tinyNaturalX: float = grid.mMajorXSpace.float * stpScale / (divs^2)
      tinyNaturalY: float = grid.mMajorYSpace.float * stpScale / (divs^2)
      tinyRoundX: float = tinyNaturalX.round
      tinyRoundY: float = tinyNaturalY.round
      tinyIsZeroX: bool = tinyRoundX == 0.0
      tinyIsZeroY: bool = tinyRoundY == 0.0
      tinyFinalX: float = if tinyIsZeroX: 1.0 
                          else: tinyRoundX
      tinyFinalY: float = if tinyIsZeroY: 1.0 
                          else: tinyRoundY

      # Minor is independent
      minorNaturalX: float = grid.mMajorXSpace.float * stpScale / divs
      minorNaturalY: float = grid.mMajorYSpace.float * stpScale / divs
      minorRoundX: float = minorNaturalX.round
      minorRoundY: float = minorNaturalY.round
      minorIsRoundedX: bool = minorNaturalX != minorRoundX
      minorIsRoundedY: bool = minorNaturalY != minorRoundY
      minorIsZeroX: bool = minorRoundX == 0.0
      minorIsZeroY: bool = minorRoundY == 0.0
      minorFinalX: float = if minorIsZeroX: 1.0
                           else: minorRoundX
      minorFinalY: float = if minorIsZeroY: 1
                           else: minorRoundY

      # Major depends on minor
      majorNaturalX: float = grid.mMajorXSpace.float * stpScale
      majorNaturalY: float = grid.mMajorYSpace.float * stpScale
      majorRoundX: float = majorNaturalX.round
      majorRoundY: float = majorNaturalY.round
      majorFinalX: float = if minorIsZeroX: 1.0
                           elif minorIsRoundedX: minorFinalX * divs
                           else: majorRoundX
      majorFinalY: float = if minorIsZeroY: 1
                           elif minorIsRoundedY: minorFinalY * divs
                           else: majorRoundY

    case scale
    of None: (1, 1)
    of Tiny: (tinyFinalX.WType, tinyFinalY.WType)
    of Minor: (minorFinalX.WType, minorFinalY.WType)
    of Major: (majorFinalX.WType, majorFinalY.WType)
  elif WType is SomeFloat:
    let 
      majorX: float = grid.mMajorXSpace * stpScale
      majorY: float = grid.mMajorYSpace * stpScale
      minorX: float = grid.mMajorXSpace * stpScale / divs
      minorY: float = grid.mMajorYSpace * stpScale / divs
      tinyX:  float = grid.mMajorXSpace * stpScale / (divs^2)
      tinyY:  float = grid.mMajorYSpace * stpScale / (divs^2)
    case scale
    of None: (0.0, 0.0)
    of Tiny: (tinyX, tinyY)
    of Minor: (minorX, minorY)
    of Major: (majorX, majorY)

proc recommendScale*(grid: Grid, modifier: bool): Scale =
  # Recommend a snapping scale based on current zoom level
  # If modifier is true, recommend a finer scale
  if grid.mSnap:
    let minorValid = grid.areMinorDivisionsValid()
    let tinyValid = grid.areTinyDivisionsValid()
    if modifier and tinyValid: Tiny
    elif modifier: None
    elif minorValid: Minor
    elif tinyValid: Tiny
    else: None
  else: None

proc snap*[T:tuple[x, y: SomeNumber]](pt: T, grid: Grid, scale: Scale): T =
  # Round to nearest minor grid point
  # Returns same type of point as is passed in.
  # If this is a WPoint, and that is integer-based, then
  # rounding will occur in implicit conversion
  let md = minDelta(grid, scale)
  when WType is SomeFloat:
    if md == (0.0, 0.0): return pt
  elif WType is Someinteger:
    if md == (1, 1): 
      when T is SomeFloat:
        return pt.round
    elif T is SomeInteger:
        return pt
  let
    xcnt:  float = (pt[0] / md.x).round
    ycnt:  float = (pt[1] / md.y).round
    xsnap: float = xcnt * md.x.float
    ysnap: float = ycnt * md.y.float
  (xsnap, ysnap)

proc lineAlpha(step: int): int =
  let idx = max(0, step - alphaOffset)
  if idx < stepAlphas.len:
    result = stepAlphas[idx]
  else:
    result = 255
proc toWorldF(pt: PxPoint, vp: Viewport): tuple[x,y: float] =
  let
    x = ((pt.x - vp.pan.x).float / vp.zoom)
    y = ((pt.y - vp.pan.y).float / vp.zoom)
  (x, y)


proc draw*(grid: Grid, vp: Viewport, rp: RendererPtr, size: wSize) =
  # Grid spaces are in world coords.  Need to convert to pixels
  let
    upperLeft: PxPoint = (0, 0)
    lowerRight: PxPoint = (size.width - 1, size.height - 1)

  if grid.mVisible:
    let
      worldStartMinor: tuple[x, y: float] = upperLeft.toWorldF(vp).snap(grid, scale=Minor)
      worldEndMinor:   tuple[x, y: float] = lowerRight.toWorldF(vp).snap(grid, scale=Minor)
      worldStepMinor:  tuple[x, y: WType] = minDelta(grid, scale=Minor)
      worldStartMajor: tuple[x, y: float] = upperLeft.toWorldF(vp).snap(grid, scale=Major)
      worldEndMajor:   tuple[x, y: float] = lowerRight.toWorldF(vp).snap(grid, scale=Major)
      worldStepMajor:  tuple[x, y: WType] = minDelta(grid, scale=Major)
      xStepPxColor:    int = (worldStepMinor.x.float * vp.zoom).round.int

    # Minor lines
    if grid.mDotsOrLines == Lines:
      rp.setDrawColor(LightSlateGray.toColorU32(lineAlpha(xStepPxColor)).toColor)
      for xwf in arange(worldStartMinor.x .. worldEndMinor.x, worldStepMinor.x.float):
        let xpx = (xwf * vp.zoom + vp.pan.x.float).round.cint
        rp.drawLine(xpx, 0, xpx, size.height - 1)

      for ywf in arange(worldStartMinor.y .. worldEndMinor.y, worldStepMinor.y.float):
        let ypx = (ywf * vp.zoom + vp.pan.y.float).round.cint
        rp.drawLine(0, ypx, size.width - 1, ypx)

    elif grid.mDotsOrLines == Dots:
      var pts: seq[Point]
      rp.setDrawColor(LightSlateGray.toColorU32(lineAlpha(xStepPxColor)).toColor)
      for xwf in arange(worldStartMinor.x .. worldEndMinor.x, worldStepMinor.x.float):
        let xpx = (xwf * vp.zoom + vp.pan.x.float).round.cint
        for ywf in arange(worldStartMinor.y .. worldEndMinor.y, worldStepMinor.y.float):
          let ypx = (ywf * vp.zoom + vp.pan.y.float).round.cint
          pts.add((xpx-1, ypx-1))
          pts.add((xpx-1, ypx  ))
          pts.add((xpx,   ypx-1))
          pts.add((xpx,   ypx  ))
      rp.drawPoints(cast[ptr Point](pts[0].addr), pts.len.cint)


    # Major lines
    if grid.mDotsOrLines == Lines:
      rp.setDrawColor(Black.toColor)
      for xwf in arange(worldStartMajor.x .. worldEndMajor.x, worldStepMajor.x.float):
        let xpx = (xwf * vp.zoom + vp.pan.x.float).round.cint
        rp.drawLine(xpx, 0, xpx, size.height - 1)

      for ywf in arange(worldStartMajor.y .. worldEndMajor.y, worldStepMajor.y.float):
        let ypx = (ywf * vp.zoom + vp.pan.y.float).round.cint
        rp.drawLine(0, ypx, size.width - 1, ypx)
    
    elif grid.mDotsOrLines == Dots:
      var pts: seq[Point]
      rp.setDrawColor(Black.toColor)
      for xwf in arange(worldStartMajor.x .. worldEndMajor.x, worldStepMajor.x.float):
        let xpx = (xwf * vp.zoom + vp.pan.x.float).round.cint
        for ywf in arange(worldStartMajor.y .. worldEndMajor.y, worldStepMajor.y.float):
          let ypx = (ywf * vp.zoom + vp.pan.y.float).round.cint
          pts.add((xpx-1, ypx-1))
          pts.add((xpx-0, ypx-1))
          pts.add((xpx+1, ypx-1))
          pts.add((xpx-1, ypx-0))
          pts.add((xpx-0, ypx-0))
          pts.add((xpx+1, ypx-0))
          pts.add((xpx-1, ypx+1))
          pts.add((xpx-0, ypx+1))
          pts.add((xpx+1, ypx+1))
      rp.drawPoints(cast[ptr Point](pts[0].addr), pts.len.cint)


  if grid.mOriginVisible:
    let
      extent: PxType = 25.0 * vp.zoom
      o: PxPoint = (0, 0).toPixel(vp)
        
    rp.setDrawColor(colors.DarkRed.toColor())

    # Horizontals
    rp.drawLine(o.x - extent, o.y,   o.x + extent, o.y    )
    rp.drawLine(o.x - extent, o.y-1, o.x + extent, o.y - 1)
    rp.drawLine(o.x - extent, o.y+1, o.x + extent, o.y + 1)
    
    # Verticals
    rp.drawLine(o.x,     o.y - extent, o.x,     o.y + extent)
    rp.drawLine(o.x - 1, o.y - extent, o.x - 1, o.y + extent)
    rp.drawLine(o.x + 1, o.y - extent, o.x + 1, o.y + extent)

proc newGrid*(zCtrl: ZoomCtrl): Grid = 
  result = new Grid
  result.mZctrl = zCtrl
  result.divisions = gGridSpecsJ["divisions"].getInt
  result.majorXSpace = gGridSpecsJ["majorXSpace"].getInt
  result.majorYSpace = gGridSpecsJ["majorYSpace"].getInt
  result.mVisible = gGridSpecsJ["visible"].getBool
  result.mOriginVisible = gGridSpecsJ["originVisible"].getBool
  result.mSnap = gGridSpecsJ["snap"].getBool
  result.mDotsOrLines = 
    if gGridSpecsJ["dotsOrLines"].getStr == "dots": Dots
    elif gGridSpecsJ["dotsOrLines"].getStr == "lines": Lines
    else: raise newException(ValueError, "Select dots or lines")

when isMainModule:
  let zc = newZoomCtrl(base=4, clickDiv=2400, maxPwr=3, density=1.0)
  let gr = newGrid(zc)
  echo gr[]