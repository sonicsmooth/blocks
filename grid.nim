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
    ySpace*: WType = 200
    visible*: bool = true
    originVisible*: bool = true

const
  stepAlphas = arange(0 .. 255, 10).toSeq

proc snap*(pt: WPoint, grid: Grid): WPoint =
  # Round to nearest grid point
  let xcnt = (pt.x / grid.xSpace).round
  let ycnt = (pt.y / grid.ySpace).round
  (xcnt * grid.xSpace, ycnt * grid.ySpace)

proc snap*(grid: Grid, pt: WPoint): WPoint =
  # Round to nearest grid point
  let xcnt = (pt.x / grid.xSpace).round
  let ycnt = (pt.y / grid.ySpace).round
  (xcnt * grid.xSpace, ycnt * grid.ySpace)

proc lineAlpha(step: int): int =
  if step < stepAlphas.len:
    stepAlphas[step]
  else:
    255

proc draw*(grid: Grid, vp: ViewPort, rp: sdl2.RendererPtr, size: wSize) =
  # Grid spaces are in world coords.  Need to convert to pixels
  let
    worldStart: WPoint = (0, 0).toWorld(vp).snap(grid)
    worldEnd: WPoint   = (size.width - 1, size.height - 1).toWorld(vp).snap(grid)
    xstep: float = grid.xSpace.float * vp.zoom
    ystep: float = grid.ySpace.float * vp.zoom
  
  rp.setDrawColor(LightSlateGray.toColor(lineAlpha(xstep.round.int)))


  if xstep >= 2.0:
    for x in arange(worldStart.x .. worldEnd.x, grid.xSpace):
      let xp = x.toPixelX(vp)
      rp.drawLine(xp, 0, xp, size.height - 1)

  if ystep >= 2.0:
    for y in arange(worldStart.y .. worldEnd.y, grid.ySpace):
      let yp = y.toPixelY(vp)
      rp.drawLine(0, yp, size.width - 1, yp)

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

  
