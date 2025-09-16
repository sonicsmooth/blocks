import std/math
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

echo Grid()

proc snap*(pt: world.Point, grid: Grid): world.Point =
  # Round to nearest grid point
  let xcnt: int = (pt.x / grid.xSpace).round.int
  let ycnt: int = (pt.y / grid.ySpace).round.int
  (xcnt * grid.xSpace, ycnt * grid.ySpace)

proc snap*(grid: Grid, pt: world.Point): world.Point =
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
    xstep  = (grid.xSpace * vp.zoom).cint
    ystep  = (grid.ySpace * vp.zoom).cint

  for x in arange(pxStart.x .. pxEnd.x, xstep):
    rp.drawLine(x, 0, x, size.height.cint)
  
  for y in arange(pxStart.y .. pxEnd.y, ystep):
    rp.drawLine(0, y, size.width.cint, y)
  
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
  
