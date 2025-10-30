import std/[math, sequtils, sugar, strformat]
import sdl2
import colors
from arange import arange
import viewport, pointmath
import appinit
import wNim/wTypes


type
  Scale* = enum None, Tiny, Minor, Major
  DotsOrLines* = enum Dots, Lines
  # TODO: When these change they should trigger a refresh right away
  Grid* = ref object
    mMinorXSpace: WType
    mMinorYSpace: WType
    mMajorXSpace: WType
    mMajorYSpace: WType
    mVisible*:       bool = true
    mOriginVisible*: bool = true
    mSnap*:          bool = true
    mDynamic*:       bool = true
    mDotsOrLines*: DotsOrLines = Lines
    mZctrl*:       ZoomCtrl

const
  alphaOffset = 20 
  stepAlphas = arange(60 .. 255, alphaOffset).toSeq

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

proc `majorXSpace`*(grid: Grid): WType =
  grid.mMajorXSpace

proc `majorYSpace`*(grid: Grid): WType =
  grid.mMajorXSpace

proc `majorXSpace=`(grid: Grid, val: WType) =
  when Wtype is SomeInteger:
    grid.mMinorXSpace = val div grid.mZctrl.base
  elif WType is SomeFloat:
    grid.mMinorXSpace = val / grid.mZctrl.base

proc `majorYSpace=`(grid: Grid, val: WType) =
  when Wtype is SomeInteger:
    grid.mMinorYSpace = val div grid.mZctrl.base
  elif WType is SomeFloat:
    grid.mMinorYSpace = val / grid.mZctrl.base

proc minDelta*[T](grid: Grid, scale: Scale): tuple[x,y: T] =
  # Return minimum grid spacing
  # When zoom in, stpScale is a large value
  # When grid.snap is false, returns minimum
  let
    zc = grid.mZctrl
    stpScale: float = pow(zc.base.float, zc.logStep.float)
    minorXSpace: float = grid.mMinorXSpace.float
    minorYSpace: float = grid.mMinorYSpace.float
  when T is SomeInteger:
    # Compute minor grid first, then others
    let minorX: float = max(minorXSpace / stpScale, 1.0)
    let minorY: float = max(minorYSpace / stpScale, 1.0)
    case scale
    of None:
      (1, 1)
    of Tiny: 
      let
        tinyX: float = max(minorX / zc.base.float, 1.0)
        tinyY: float = max(minorY / zc.base.float, 1.0)
      (tinyX.round.int, tinyY.round.int)
    of Minor:
      (minorX.round.int, minorY.round.int)
    of Major:
      let
        majorX: float = minorX.round * zc.base.float
        majorY: float = minorY.round * zc.base.float
      (majorX.round.int, majorY.round.int)
  elif T is SomeFloat:
    let 
      minorX: float = minorXSpace.float / stpScale
      minorY: float = minorYSpace.float / stpScale
    case scale
    of None:
      (0.0, 0.0)
    of Tiny:
      (minorX, minorY) * (1.0 / zc.base.float)
    of Minor:
      (minorX, minorY)
    of Major:
      (minorX, minorY) * zc.base.float

proc snap*[T:tuple[x, y: SomeNumber]](pt: T, grid: Grid, scale: Scale): T =
  # Round to nearest minor grid point
  # Returns same type of point as is passed in.
  # If this is a WPoint, and that is integer-based, then
  # rounding will occur in implicit conversion
  let md = minDelta[WType](grid, scale)
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

proc draw*(grid: Grid, vp: Viewport, rp: RendererPtr, size: wSize) =
  # Grid spaces are in world coords.  Need to convert to pixels
  let
    upperLeft: PxPoint = (0, 0)
    lowerRight: PxPoint = (size.width - 1, size.height - 1)

  # Minor lines
  if grid.mVisible:
    let
      worldStartMinor: tuple[x, y: float] = upperLeft.toWorldF(vp).snap(grid, scale=Minor)
      worldEndMinor:   tuple[x, y: float] = lowerRight.toWorldF(vp).snap(grid, scale=Minor)
      worldStepMinor:  tuple[x, y: WType] = minDelta[WType](grid, scale=Minor)
      xStepPxColor:    int = (worldStepMinor.x.float * vp.zoom).round.int
    rp.setDrawColor(LightSlateGray.toColorU32(lineAlpha(xStepPxColor)).toColor)
    for xwf in arange(worldStartMinor.x .. worldEndMinor.x, worldStepMinor.x.float):
      let xpx = (xwf * vp.zoom + vp.pan.x.float).round.int
      rp.drawLine(xpx, 0, xpx, size.height - 1)

    for ywf in arange(worldStartMinor.y .. worldEndMinor.y, worldStepMinor.y.float):
      let ypx = (ywf * vp.zoom + vp.pan.y.float).round.int
      rp.drawLine(0, ypx, size.width - 1, ypx)

    # Major lines
    let
      worldStartMajor: tuple[x, y: float] = upperLeft.toWorldF(vp).snap(grid, scale=Major)
      worldEndMajor:   tuple[x, y: float] = lowerRight.toWorldF(vp).snap(grid, scale=Major)
      worldStepMajor:  tuple[x, y: WType] = minDelta[WType](grid, scale=Major)
    rp.setDrawColor(Black.toColor)
    for xwf in arange(worldStartMajor.x .. worldEndMajor.x, worldStepMajor.x.float):
      let xpx = (xwf * vp.zoom + vp.pan.x.float).round.int
      rp.drawLine(xpx, 0, xpx, size.height - 1)

    for ywf in arange(worldStartMajor.y .. worldEndMajor.y, worldStepMajor.y.float):
      let ypx = (ywf * vp.zoom + vp.pan.y.float).round.int
      rp.drawLine(0, ypx, size.width - 1, ypx)

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

proc newGrid*(zc: ZoomCtrl): Grid = 
  result = new Grid
  result.mZctrl = zc
  # result.minorXSpace = gGridSpecsJ["minorXSpace"].getInt
  # result.minorYSpace = gGridSpecsJ["minorYSpace"].getInt
  # result.mMajorXSpace = gGridSpecsJ["majorXSpace"].getInt
  # result.mMajorYSpace = gGridSpecsJ["majorYSpace"].getInt
  result.majorXSpace = gGridSpecsJ["majorXSpace"].getInt
  result.majorYSpace = gGridSpecsJ["majorYSpace"].getInt
  result.mVisible = gGridSpecsJ["visible"].getBool
  result.mOriginVisible = gGridSpecsJ["originVisible"].getBool
  result.mSnap = gGridSpecsJ["snap"].getBool
  result.mDynamic = gGridSpecsJ["dynamic"].getBool
  result.mDotsOrLines = 
    if gGridSpecsJ["dotsOrLines"].getStr == "dots": Dots
    elif gGridSpecsJ["dotsOrLines"].getStr == "lines": Lines
    else: raise newException(ValueError, "Select dots or lines")

when isMainModule:
  let zc = newZoomCtrl(base=4, clickDiv=2400, maxPwr=3, density=1.0)
  let gr = newGrid(zc)
  echo gr[]