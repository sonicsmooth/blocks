import std/[math, sequtils, strformat, sugar]
import sdl2
import colors
from arange import arange
import viewport
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

proc adjustedZoom(vp: ViewPort, major: bool=false): float =
  # Return zoom after adjusting for zoom levels
  # Used for computing snap and spacing
  # This computes the regular zoom except keeps its range between
  # [1.0:base) * density
  # usually zoom is base ^ (clicks / div)
  # in this case we want to keeps clicks within [0:div) and wrap around 
  # as determined by logStep.
  let 
    clickOffset = (vp.zctrl.logStep + major) * vp.zctrl.clickDiv
    numerator = vp.zClicks - clickOffset
    adjExp = numerator / vp.zctrl.clickDiv
  pow(vp.zctrl.base, adjExp) * vp.zctrl.density

proc stepScale(vp: ViewPort, major: bool=false): float =
  # The scaling used by a few things at different levels
  # The scaling is fixed for a range of zooms
  pow(vp.zctrl.base.float, vp.zctrl.logStep.float + major.float)

proc snap*(pt: WPoint, grid: Grid, vp: ViewPort, major: bool=false): WPoint =
  # Round to nearest minor grid point
  let
    localXSpace = grid.xSpace.float / stepScale(vp, major)
    localYSpace = grid.ySpace.float / stepScale(vp, major)
    xcnt = (pt.x / localXSpace).round
    ycnt = (pt.y / localYSpace).round
    xsnap = xcnt * localXSpace
    ysnap = ycnt * localXSpace
  #echo &"pt: {pt.x}; localXSpace: {localXSpace}; xcnt: {xcnt}; xsnap: {xsnap}"
  (x: xsnap, y: ysnap)




proc draw*(grid: Grid, vp: ViewPort, rp: RendererPtr, size: wSize) =
  # Grid spaces are in world coords.  Need to convert to pixels

  # We need to repeat some of the same eqns as in zoom
  # to get the proper step sizes

  let toWrld = proc(pt: PxPoint): WPoint =
    let x = ((pt.x - vp.pan.x).float / vp.zoom).round.cint
    let y = ((pt.y - vp.pan.y).float / vp.zoom).round.cint
    (x, y)

  let
    worldStart: WPoint = (0, 0).toWrld.snap(grid, vp)
    worldEnd: WPoint = (size.width - 1, size.height - 1).toWrld.snap(grid, vp)
    pxStart: PxPoint = toPixel(worldStart, vp)
    pxEnd: PxPoint = toPixel(worldEnd, vp)
    az = adjustedZoom(vp)
    xPxStep: float = grid.xSpace.float * az
    yPxStep: float = grid.ySpace.float * az
   
  echo ""
  echo worldStart.x
  dump pxStart.x

  # # #rp.setDrawColor(LightSlateGray.toColor(lineAlpha(xStepPx.round.int)))
  rp.setDrawColor(LightSlateGray.toColor)
  if xPxStep >= 2.0:
    for xpxf in arange(pxStart.x.float .. pxEnd.x.float, xPxStep):
      let xpx = xpxf.round.int
      rp.drawLine(xpx, 0, xpx, size.height - 1)

  # if yStepPx >= 2:
  #   for y in arange(worldStart.y .. worldEnd.y, grid.ySpace):
  #     let yp = (y.float * stepZoom + vp.pan.y.float).round.int
  #     rp.drawLine(0, yp, size.width - 1, yp)

  # let
  #   worldStartBig: WPoint = (0, 0).toWrld.snap(grid, vp, major=true)
  #   worldEndBig: WPoint = (size.width - 1, size.height - 1).toWrld.snap(grid, vp, major=true)
  #   xStepPxBig = (grid.xSpace.float * vp.zctrl.base.float * stepZoom).round.int
  #   yStepPxBig = (grid.ySpace.float * vp.zctrl.base.float * stepZoom).round.int
  
  # # #rp.setDrawColor(Red.toColor(lineAlpha(xStepPxBig.round.int)))
  # rp.setDrawColor(Black.toColor)
  # if xStepPxBig >= 2 * vp.zctrl.base:
  #   for x in arange(worldStartBig.x .. worldEndBig.x, grid.xSpace * vp.zctrl.base):
  #     let xp = (x.float * stepZoom + vp.pan.x.float).round.int
  #     rp.drawLine(xp, 0, xp, size.height - 1)

  # if yStepPxBig >= 2 * vp.zctrl.base:
  #   for y in arange(worldStartBig.y .. worldEndBig.y, grid.ySpace * vp.zctrl.base):
  #     let yp = (y.float * stepZoom + vp.pan.y.float).round.int
  #     rp.drawLine(0, yp, size.width - 1, yp)

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

  
