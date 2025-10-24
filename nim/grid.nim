import std/[math, sequtils]
import sdl2
import colors
from arange import arange
import viewport, pointmath
import appinit
import wNim/wTypes


type
  Scale* = enum None, Tiny, Minor, Major
  DotsOrLines* = enum Dots, Lines
  Grid* = ref object
    xSpace*: WType = 10 #TODO leave as defaults
    ySpace*: WType = 10
    visible*: bool = true
    originVisible*: bool = true
    snap*: bool = true
    dynamic*: bool = true
    dotsOrLines*: DotsOrLines = Lines

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

proc minDelta*[T](grid: Grid, vp: Viewport, scale: Scale): tuple[x,y: T] =
  # Return minimum grid spacing
  # When zoom in, stepScale returns a large value
  let 
    stpScale: float = pow(vp.zctrl.base.float, vp.zctrl.logStep.float)
    xSpace: float = grid.xSpace.float
    ySpace: float = grid.ySpace.float
  when T is SomeInteger:
    # Compute minor grid first, then others
    let minorX: float = max(xSpace / stpScale, 1.0)
    let minorY: float = max(ySpace / stpScale, 1.0)
    case scale
    of None:
      (1, 1)
    of Tiny: 
      let
        tinyX: float = max(minorX / vp.zctrl.base.float, 1.0)
        tinyY: float = max(minorY / vp.zctrl.base.float, 1.0)
      (tinyX.round.int, tinyY.round.int)
    of Minor:
      (minorX.round.int, minorY.round.int)
    of Major:
      let
        majorX: float = minorX * vp.zctrl.base.float
        majorY: float = minorY * vp.zctrl.base.float
      (majorX.round.int, majorY.round.int)
  elif T is SomeFloat:
    let 
      minorX: float = xSpace.float / stpScale
      minorY: float = ySpace.float / stpScale
    case scale
    of None:
      (0.0, 0.0)
    of Tiny:
      (minorX, minorY) * (1.0 / vp.zctrl.base.float)
    of Minor:
      (minorX, minorY)
    of Major:
      (minorX, minorY) * vp.zctrl.base.float

proc snap*[T:tuple[x, y: SomeNumber]](pt: T, grid: Grid, vp: Viewport, scale: Scale): T =
  # Round to nearest minor grid point
  # Returns same type of point as is passed in.
  # If this is a WPoint, and that is integer-based, then
  # rounding will occur in implicit conversion
  let md = minDelta[WType](grid, vp, scale)
  when WType is SomeFloat:
    if md == (0.0, 0.0): return pt
  elif WType is Someinteger:
    if md == (1, 1): return pt
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
    worldStart = upperLeft.toWorldF(vp).snap(grid, vp, scale=Minor)
    worldEnd   = (size.width - 1, size.height - 1).toWorldF(vp).snap(grid, vp, scale=Minor)
    worldStep  = minDelta[WType](grid, vp, scale=Minor)
    xStepPx    = (worldStep.x.float * vp.zoom).round.int

    worldStartMajor = upperLeft.toWorldF(vp).snap(grid, vp, scale=Major)
    worldEndMajor = (size.width - 1, size.height - 1).toWorldF(vp).snap(grid, vp, scale=Major)
    worldStepMajor = minDelta[WType](grid, vp, scale=Major)

  # Minor lines
  rp.setDrawColor(LightSlateGray.toColorU32(lineAlpha(xStepPx)).toColor)
  for xwf in arange(worldStart.x .. worldEnd.x, worldStep.x.float):
    let xpx = (xwf * vp.zoom + vp.pan.x.float).round.int
    rp.drawLine(xpx, 0, xpx, size.height - 1)

  for ywf in arange(worldStart.y .. worldEnd.y, worldStep.y.float):
    let ypx = (ywf * vp.zoom + vp.pan.y.float).round.int
    rp.drawLine(0, ypx, size.width - 1, ypx)

  # Major lines
  rp.setDrawColor(Black.toColor)
  for xwf in arange(worldStartMajor.x .. worldEndMajor.x, worldStepMajor.x.float):
    let xpx = (xwf * vp.zoom + vp.pan.x.float).round.int
    rp.drawLine(xpx, 0, xpx, size.height - 1)

  for ywf in arange(worldStartMajor.y .. worldEndMajor.y, worldStepMajor.y.float):
    let ypx = (ywf * vp.zoom + vp.pan.y.float).round.int
    rp.drawLine(0, ypx, size.width - 1, ypx)

  if grid.originVisible:
    let
      extent: PxType = 25.0 * vp.zoom
      o = (0, 0).toPixel(vp)
        
    rp.setDrawColor(colors.DarkRed.toColor())

    # Horizontals
    rp.drawLine(o.x - extent, o.y,   o.x + extent, o.y    )
    rp.drawLine(o.x - extent, o.y-1, o.x + extent, o.y - 1)
    rp.drawLine(o.x - extent, o.y+1, o.x + extent, o.y + 1)
    
    # Verticals
    rp.drawLine(o.x,     o.y - extent, o.x,     o.y + extent)
    rp.drawLine(o.x - 1, o.y - extent, o.x - 1, o.y + extent)
    rp.drawLine(o.x + 1, o.y - extent, o.x + 1, o.y + extent)

proc newGrid*(): Grid = 
  result = new Grid
  result.xSpace = gGridSpecsJ["xSpace"].getInt
  result.ySpace = gGridSpecsJ["ySpace"].getInt
  result.visible = gGridSpecsJ["visible"].getBool
  result.originVisible = gGridSpecsJ["originVisible"].getBool
  result.snap = gGridSpecsJ["snap"].getBool
  result.dynamic = gGridSpecsJ["dynamic"].getBool
  result.dotsOrLines = 
    if gGridSpecsJ["dotsOrLines"].getStr == "dots": Dots
    elif gGridSpecsJ["dotsOrLines"].getStr == "lines": Lines
    else: raise newException(ValueError, "Select dots or lines")

when isMainModule:
  let gr = newGrid()
  echo gr[]