import std/[math, sugar]
import sdl2
import colors
from arange import arange
import viewport
import world
import wNim/wTypes

type
  Grid* = object
    xSpace*: WCoordT = 10
    ySpace*: WCoordT = 10
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
    worldStart = vp.toWorld((0, size.height)).snap(grid)
    worldEnd   = vp.toWorld((size.width, 0)).snap(grid)
    pxStart = vp.toPixel(worldStart)
    pxEnd = vp.toPixel(worldEnd)
    xstep  = (grid.xSpace.float * vp.zoom)
    ystep  = (grid.ySpace.float * vp.zoom)
  
  #dump xstep

  if xstep >= 10.0:
    for x in arange(pxStart.x.float .. pxEnd.x.float, xstep):
      let xr = x.round.cint
      rp.drawLine(xr, 0, xr, size.height.cint)
    
    for y in arange(pxStart.y.float .. pxEnd.y.float, ystep):
      let yr = y.round.cint
      rp.drawLine(0, yr, size.width.cint, yr)
  
  if grid.originVisible:
    var pt1, pt2: sdl2.Point
    let extent = 25.0
    let offset = 1.0
    let perps = [-offset, 0.0, offset]
    rp.setDrawColor(colors.DarkRed.toColor())
    for y in perps:
      pt1 = vp.toPixel((-extent,  y))
      pt2 = vp.toPixel(( extent,  y))
      rp.drawLine(pt1.x, pt1.y, pt2.x, pt2.y)
    for x in perps:
      pt1 = vp.toPixel((x, -extent))
      pt2 = vp.toPixel((x,  extent))
      rp.drawLine(pt1.x, pt1.y, pt2.x, pt2.y)
  
