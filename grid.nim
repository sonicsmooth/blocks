import std/[math, sugar]
import sdl2
import colors
from arange import arange
import viewport
import world
import wNim/wTypes

type
  Grid* = object
    xSpace*: WType = 10
    ySpace*: WType = 10
    visible*: bool = true
    originVisible*: bool = true

proc snap*(pt: WPoint, grid: Grid): WPoint =
  # Round to nearest grid point
  let xcnt: int = (pt.x / grid.xSpace).round.int
  let ycnt: int = (pt.y / grid.ySpace).round.int
  (xcnt * grid.xSpace, ycnt * grid.ySpace)

proc snap*(grid: Grid, pt: WPoint): WPoint =
  # Round to nearest grid point
  let xcnt: int = (pt.x / grid.xSpace).round.int
  let ycnt: int = (pt.y / grid.ySpace).round.int
  (xcnt * grid.xSpace, ycnt * grid.ySpace)

proc draw*(grid: Grid, vp: ViewPort, rp: sdl2.RendererPtr, size: wSize) =
  # Grid spaces are in world coords.  Need to convert to pixels
  rp.setDrawColor(colors.LightSlateGray.toColor())
  let
    worldStart: WPoint = (0, size.height).toWorld(vp).snap(grid)
    worldEnd: WPoint   = (size.width, 0).toWorld(vp).snap(grid)
    pxStart: PxPoint = worldStart.toPixel(vp)
    pxEnd: PxPoint = worldEnd.toPixel(vp)
    xstep: float  = (grid.xSpace.float * vp.zoom)
    ystep: float  = (grid.ySpace.float * vp.zoom)
  

  if xstep >= 5.0:
    for x in arange(pxStart.x.float .. pxEnd.x.float, xstep):
      let xr = x.round.cint
      rp.drawLine(xr, 0, xr, size.height.cint)
    
    for y in arange(pxStart.y.float .. pxEnd.y.float, ystep):
      let yr = y.round.cint
      rp.drawLine(0, yr, size.width.cint, yr)
  
  if grid.originVisible:
    let
      extent: PxType = (25.0 * vp.zoom).toPxType
      o: PxPoint = (0, 0).toPixel(vp)
        
    rp.setDrawColor(colors.DarkRed.toColor())

    # Horizontals
    rp.drawLine(o.x - extent, o.y,   o.x + extent, o.y    )
    #rp.drawLine(o.x - extent, o.y-1, o.x + extent, o.y - 1)
    #rp.drawLine(o.x - extent, o.y+1, o.x + extent, o.y + 1)
    
    # Verticals
    rp.drawLine(o.x,     o.y - extent, o.x,     o.y + extent)
    #rp.drawLine(o.x - 1, o.y - extent, o.x - 1, o.y + extent)
    #rp.drawLine(o.x + 1, o.y - extent, o.x + 1, o.y + extent)

  
