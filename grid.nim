import std/[math, sequtils, strformat, sugar]
import sdl2
import colors
from arange import arange
import viewport, pointmath
import wNim/wTypes

type
  Grid* = object
    xSpace*: WType = 50
    ySpace*: WType = 50
    visible*: bool = true
    originVisible*: bool = true

const stepAlphas = arange(0 .. 255, 10).toSeq
proc lineAlpha(step: int): int =
  if step < stepAlphas.len:
    stepAlphas[step]
  else:
    255

# proc adjustedZoom(vp: ViewPort, major: bool=false): float =
#   # Return zoom after adjusting for zoom levels
#   # Used for computing snap and spacing
#   # This computes the regular zoom except keeps its range between
#   # [1.0:base) * density
#   # usually zoom is base ^ (clicks / div)
#   # in this case we want to keeps clicks within [0:div) and wrap around 
#   # as determined by logStep.
#   let 
#     clickOffset = (vp.zctrl.logStep + major) * vp.zctrl.clickDiv
#     numerator = vp.zClicks - clickOffset
#     adjExp = numerator / vp.zctrl.clickDiv
#   pow(vp.zctrl.base.float, adjExp) * vp.zctrl.density

proc stepScale(vp: ViewPort): float =
  # The scaling used by a few things at different levels
  # The scaling is fixed for a range of zooms
  pow(vp.zctrl.base.float, vp.zctrl.logStep.float)

proc toWorldF(pt: PxPoint, vp: ViewPort): tuple[x,y: float] =
  let
    x = ((pt.x - vp.pan.x).float / vp.zoom)
    y = ((pt.y - vp.pan.y).float / vp.zoom)
  (x, y)


proc minDelta*[T](grid: Grid, vp: ViewPort): tuple[x,y: T] =
  # Return minimum visible grid spacing
  # When zoom in, stepScale returns a large value
  let 
    ss: float = stepScale(vp)
    xs: float = grid.xSpace.float
    ys: float = grid.ySpace.float
  when T is SomeInteger:
    # Truncate before it gets rounded, maybe, by implicit conversion
    # Whether it gets rounded depends on whether T is WType and WType is int
    let x = max((xs / ss).int, 1)
    let y = max((ys / ss).int, 1)
    (x, y)
  elif T is SomeFloat:
    (xs / ss, ys / ss)

proc snap*[T:tuple[x, y: SomeNumber]](pt: T, grid: Grid, vp: ViewPort, major: bool=false): T =
  # Round to nearest minor grid point
  # Returns same type of point as is passed in.
  # If this is a WPoint, and that is integer-based, then
  # rounding will occur in implicit conversion
  let
    md =
      if major: minDelta[WType](grid, vp) * vp.zctrl.base.WType
      else:     minDelta[WType](grid, vp)
    xcnt:  float = (pt[0] / md.x).round
    ycnt:  float = (pt[1] / md.y).round
    xsnap: float = xcnt * md.x.float
    ysnap: float = ycnt * md.y.float
  (xsnap, ysnap)

proc draw*(grid: Grid, vp: ViewPort, rp: RendererPtr, size: wSize) =
  # Grid spaces are in world coords.  Need to convert to pixels
  let
    upperLeft: PxPoint = (50, 50)
    worldStart = upperLeft.toWorldF(vp).snap(grid, vp, major=false)
    worldEnd = (size.width - 1, size.height - 1).toWorldF(vp).snap(grid, vp, major=false)
    worldStep = minDelta[WType](grid, vp)

    worldStartMajor = upperLeft.toWorldF(vp).snap(grid, vp, major=true)
    worldEndMajor = (size.width - 1, size.height - 1).toWorldF(vp).snap(grid, vp, major=true)
    worldStepMajor = worldStep * vp.zctrl.base
   
  #echo &"ws.x: {worldStart.y}; wsm.x: {worldStartMajor.y}"
  rp.setDrawColor(Red.toColor)
  rp.drawLine(upperLeft.x, upperLeft.y, upperLeft.x + 100, upperLeft.y)
  rp.drawLine(upperLeft.x, upperLeft.y, upperLeft.x, upperLeft.y + 100)

  rp.setDrawColor(LightSlateGray.toColor)
  for xwf in arange(worldStart.x .. worldEnd.x, worldStep.x.float):
    let xpx = (xwf * vp.zoom + vp.pan.x.float).round.int
    rp.drawLine(xpx, 0, xpx, size.height - 1)

  for ywf in arange(worldStart.y .. worldEnd.y, worldStep.y.float):
    let ypx = (ywf * vp.zoom + vp.pan.y.float).round.int
    rp.drawLine(0, ypx, size.width - 1, ypx)

  
  rp.setDrawColor(Black.toColor)
  for xwf in arange(worldStartMajor.x .. worldEndMajor.x, worldStepMajor.x.float):
    let xpx = (xwf * vp.zoom + vp.pan.x.float).round.int
    rp.drawLine(xpx, 0, xpx, size.height - 1)

  for ywf in arange(worldStartMajor.y .. worldEndMajor.y, worldStepMajor.y.float):
    let ypx = (ywf * vp.zoom + vp.pan.x.float).round.int
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

  
