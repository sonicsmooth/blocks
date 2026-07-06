import std/[algorithm, 
            math, 
            sequtils, 
            #strformat
            ]
#import sdl2
import colors
import viewport, pointmath #, renderer
import appinit
import wNim/wTypes


type
  Scale* = enum None, Tiny, Minor, Major
  DotsOrLines* = enum Dots, Lines
  DivRange* = range[2..16]
  Grid* = ref object
    mRefXSpace: float # Major Spacing when zoom level is 0
    mRefYSpace: float # Major Spacing when zoom level is 0
    mMajorXSpace*: WType # Written to by minDelta
    mMajorYSpace*: WType # Written to by minDelta
    mDivisions:      DivRange
    mVisible*:       bool
    mOriginVisible*: bool
    mSnap*:          bool
    mDotsOrLines*: DotsOrLines = Lines
    mZctrl*:       ZoomCtrl


# Forward decl
proc minDelta*(grid: Grid, scale: Scale): WPoint

# Return cached values
# proc majorXSpace*(grid: Grid): WType = grid.mMajorXSpace
# proc majorYSpace*(grid: Grid): WType = grid.mMajorYSpace
# todo: minor, tiny 

proc `refXSpace`*(grid: Grid): float = grid.mRefXSpace
proc `refYSpace`*(grid: Grid): float = grid.mRefYSpace

proc `refXSpace=`*(grid: Grid, val: float) =
  grid.mRefXSpace = val
  grid.mMajorXSpace = grid.minDelta(Major).x

proc `refYSpace=`*(grid: Grid, val: float) =
  grid.mRefYSpace = val
  grid.mMajorYSpace = grid.minDelta(Major).y

proc allowedDivisions*(grid: Grid): seq[DivRange] =
  # Return list of allowable divisions, i.e., which
  # values in 2..16 divide major grid space evenly.
  # If the result for X and Y are different, then
  # return the intersection.  Typically the values
  # are 2,4,5,8,10,16.
  var xset, yset: set[DivRange]
  for d in DivRange.low .. DivRange.high:
    if grid.mMajorXSpace mod d == 0: xset.incl(d)
    if grid.mMajorYSpace mod d == 0: yset.incl(d)
  let isect = xset * yset
  isect.toSeq

proc allowedDivisionsStr*(grid: Grid): seq[string] =
  for d in grid.allowedDivisions:
    result.add($d)

proc divisions*(grid: Grid): int = grid.mDivisions

proc `divisions=`*(grid: var Grid, val: int): bool {.discardable.} =
  # Change grid's divisions to val
  # Returns true if given val is in allowed divisions, else false.

  # Raise exception if val is out of range
  result = val in grid.allowedDivisions()

  if grid.mZctrl.baseSync:
    grid.mZctrl.base = val
  grid.mDivisions = val
 
proc divisionsIndex*(grid: Grid): int =
  grid.allowedDivisions.find(grid.mDivisions)

proc areMinorDivisionsValid*(grid: Grid): bool =
  # True if minor grid spaces divide major grid spaces evenly
  # Generally this is false when divisions is weird or when 
  # zoomed in very far.
  when Wtype is SomeInteger:
    grid.minDelta(scale=Major).x div grid.minDelta(scale=Minor).x == grid.mDivisions and
    grid.minDelta(scale=Major).y div grid.minDelta(scale=Minor).y == grid.mDivisions
  elif WType is SomeFloat:
    true

proc areTinyDivisionsValid*(grid: Grid): bool =
  # True if tiny grid spaces divide minor grid spaces evenly
  # Generally this is false when divisions is weird or when 
  # zoomed in very far.
  when WType is SomeInteger:
    grid.minDelta(scale=Minor).x div grid.minDelta(scale=Tiny).x == grid.mDivisions and
    grid.minDelta(scale=Minor).y div grid.minDelta(scale=Tiny).y == grid.mDivisions
  elif WType is SomeFloat:
    true 

# proc calcReferenceSpace*(grid: Grid, val: WType): WType =
#   # Given a desired major grid space val,
#   # calculate the major grid space given current zoom level.
#   # At stepScale == 1.0, returns val.
#   # This value gets assigned to grid.mRef[XY]Space
#   let stpScale: float = pow(grid.mZctrl.base.float, -grid.mZctrl.logStep.float)
#   when WType is SomeInteger:
#     (val.float / stpScale).round
#   elif WType is SomeFloat:
#     val / stpScale

proc calcReferenceSpace*(grid: Grid, val: WType): float =
  # Given a desired major grid space val,
  # calculate the major grid space given current zoom level.
  # At stepScale == 1.0, returns val.
  # This value gets assigned to grid.mRef[XY]Space
  let stpScale: float = pow(grid.mZctrl.base.float, -grid.mZctrl.logStep.float)
  val.float / stpScale
  
# Todo: Cache in grid object every time something changes
# Sensitive to grid.mZctrl, grid spacing, grid divisions, scale
proc minDelta*(grid: Grid, scale: Scale): WPoint =
  # Return minimum grid spacing.
  # When zoomed in, stpScale is small and spacings are small.
  # When zoomed out, stpScale is large and spacings are large
  # scale lets you return different sizes
  let
    zc = grid.mZctrl
    stpScale: float = pow(zc.base.float, -zc.logStep.float)
    divs: float = grid.mDivisions.float

  when WType is SomeInteger:
    let
      # Tiny is independent
      tinyNaturalX: float = grid.mRefXSpace.float * stpScale / (divs^2)
      tinyNaturalY: float = grid.mRefYSpace.float * stpScale / (divs^2)
      tinyRoundX: float = tinyNaturalX.round
      tinyRoundY: float = tinyNaturalY.round
      tinyIsZeroX: bool = tinyRoundX == 0.0
      tinyIsZeroY: bool = tinyRoundY == 0.0
      tinyFinalX: float = if tinyIsZeroX: 1.0 
                          else: tinyRoundX
      tinyFinalY: float = if tinyIsZeroY: 1.0 
                          else: tinyRoundY

      # Minor is independent
      minorNaturalX: float = grid.mRefXSpace.float * stpScale / divs
      minorNaturalY: float = grid.mRefYSpace.float * stpScale / divs
      minorRoundX: float = minorNaturalX.round
      minorRoundY: float = minorNaturalY.round
      minorIsZeroX: bool = minorRoundX == 0.0
      minorIsZeroY: bool = minorRoundY == 0.0
      minorFinalX: float = if minorIsZeroX: 1.0
                           else: minorRoundX
      minorFinalY: float = if minorIsZeroY: 1
                           else: minorRoundY

      # Major is independent
      majorNaturalX: float = grid.mRefXSpace.float * stpScale
      majorNaturalY: float = grid.mRefYSpace.float * stpScale
      majorRoundX: float = majorNaturalX.round
      majorRoundY: float = majorNaturalY.round
      majorFinalX: float = if minorIsZeroX: 1.0
                           else: majorRoundX
      majorFinalY: float = if minorIsZeroY: 1
                           else: majorRoundY

    case scale
    of None: (1, 1)
    of Tiny: (tinyFinalX.WType, tinyFinalY.WType)
    of Minor: (minorFinalX.WType, minorFinalY.WType)
    of Major: (majorFinalX.WType, majorFinalY.WType)
  elif WType is SomeFloat:
    let 
      majorX: float = grid.mRefXSpace * stpScale
      majorY: float = grid.mRefYSpace * stpScale
      minorX: float = grid.mRefXSpace * stpScale / divs
      minorY: float = grid.mRefYSpace * stpScale / divs
      tinyX:  float = grid.mRefXSpace * stpScale / (divs^2)
      tinyY:  float = grid.mRefYSpace * stpScale / (divs^2)
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


proc newGrid*(zCtrl: ZoomCtrl): Grid = 
  result = new Grid
  result.mZctrl = zCtrl
  result.divisions = gGridSpecsJ["divisions"].getInt
  result.refXSpace = gGridSpecsJ["referenceXSpace"].getFloat
  result.refYSpace = gGridSpecsJ["referenceYSpace"].getFloat
  result.mVisible = gGridSpecsJ["visible"].getBool
  result.mOriginVisible = gGridSpecsJ["originVisible"].getBool
  result.mSnap = gGridSpecsJ["snap"].getBool
  result.mDotsOrLines = 
    if gGridSpecsJ["dotsOrLines"].getStr == "dots": Dots
    elif gGridSpecsJ["dotsOrLines"].getStr == "lines": Lines
    else: raise newException(ValueError, "Select dots or lines")

when isMainModule:
  let zc = newZoomCtrl(base=4, clickDiv=2400, maxPwr=3,
                       density=1.0, dynamic=true, baseSync=true)
  let gr = newGrid(zc)
  echo gr[]