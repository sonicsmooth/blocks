import std/[math, sequtils]
import sdl2
import colors
from arange import arange
import viewport
import world
import wNim/wTypes

type
  Grid* = object
    xSpace*: WType = 50
    ySpace*: WType = 50
    visible*: bool = true
    originVisible*: bool = true

const
  stepAlphas = arange(0 .. 255, 10).toSeq

proc snap*(pt: WPoint, grid: Grid): WPoint =
  # Round to nearest grid point
  let xcnt = (pt.x / grid.xSpace).round
  let ycnt = (pt.y / grid.ySpace).round
  (xcnt * grid.xSpace, ycnt * grid.ySpace)

proc snapBig*(pt: WPoint, grid: Grid): WPoint =
  # Round to nearest grid point 
  let xcnt = (pt.x / (grid.xSpace * zoomBase)).round
  let ycnt = (pt.y / (grid.ySpace * zoomBase)).round
  (xcnt * grid.xSpace * zoomBase, ycnt * grid.ySpace * zoomBase)

proc lineAlpha(step: int): int =
  if step < stepAlphas.len:
    stepAlphas[step]
  else:
    255

proc draw*(grid: Grid, vp: ViewPort, rp: RendererPtr, size: wSize) =
  # Grid spaces are in world coords.  Need to convert to pixels

  # We need to repeat some of the same eqns as in zoom
  # to get the proper step sizes
  let
    levelAdjust: float = vp.zoomLevel.float * zoomDiv.float
    preZoom: float = pow(zoomBase, (vp.zoomSteps - levelAdjust) / zoomDiv )
    stepZoom: float = preZoom * zoomDensity # use this stepZoom in this fn from here down

  let toWrld = proc(pt: PxPoint): WPoint =
    let x = ((pt.x - vp.pan.x).float / stepZoom).round.cint
    let y = ((pt.y - vp.pan.y).float / stepZoom).round.cint
    (x, y)

  let
    worldStart: WPoint = (0, 0).toWrld.snap(grid)
    worldEnd: WPoint = (size.width - 1, size.height - 1).toWrld.snap(grid)
    xStepPx = (grid.xSpace.float * stepZoom).round.int
    yStepPx = (grid.ySpace.float * stepZoom).round.int

  #rp.setDrawColor(LightSlateGray.toColor(lineAlpha(xStepPx.round.int)))
  rp.setDrawColor(LightSlateGray.toColor)
  if xStepPx >= 2:
    for x in arange(worldStart.x .. worldEnd.x, grid.xSpace):
      let xp = (x.float * stepZoom + vp.pan.x.float).round.int
      rp.drawLine(xp, 0, xp, size.height - 1)

  if yStepPx >= 2:
    for y in arange(worldStart.y .. worldEnd.y, grid.ySpace):
      let yp = (y.float * stepZoom + vp.pan.y.float).round.int
      rp.drawLine(0, yp, size.width - 1, yp)

  let
    worldStartBig: WPoint = (0, 0).toWrld.snapBig(grid)
    worldEndBig: WPoint = (size.width - 1, size.height - 1).toWrld.snapBig(grid)
    xStepPxBig = (grid.xSpace.float * zoomBase.float * stepZoom).round.int
    yStepPxBig = (grid.ySpace.float * zoomBase.float * stepZoom).round.int
  
  # #rp.setDrawColor(Red.toColor(lineAlpha(xStepPxBig.round.int)))
  rp.setDrawColor(Black.toColor)
  if xStepPxBig >= 2 * zoomBase:
    for x in arange(worldStartBig.x .. worldEndBig.x, grid.xSpace * zoomBase):
      let xp = (x.float * stepZoom + vp.pan.x.float).round.int
      rp.drawLine(xp, 0, xp, size.height - 1)

  if yStepPxBig >= 2 * zoomBase:
    for y in arange(worldStartBig.y .. worldEndBig.y, grid.ySpace * zoomBase):
      let yp = (y.float * stepZoom + vp.pan.y.float).round.int
      rp.drawLine(0, yp, size.width - 1, yp)



  if grid.originVisible:
    let
      extent: PxType = 25.0 * stepZoom
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

  
