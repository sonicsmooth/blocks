import sdl2
import colors
from arange import arange
import viewport
import world
import wNim/wTypes


type
  Grid* = object
    xSpace*: CoordT
    ySpace*: CoordT
    visible*: bool

proc draw*(grid: Grid, vp: ViewPort, rp: sdl2.RendererPtr, size: wSize) =
  # Grid spaces are in world coords.  Need to convert to pixels
  rp.setDrawColor(colors.LightSlateGray.toColor())
  let
    xstart = vp.toPixelX(0)
    xstep  = (grid.xSpace * vp.zoom).cint
    xend   = vp.toPixelX(500)
    ystart = vp.toPixelY(0)
    ystep  = (grid.ySpace * vp.zoom).cint
    yend   = vp.toPixelY(500)

  # echo vp
  # echo grid
  #echo "xstart: ", xstart
  echo "ystart -> yend: ", ystart, " -> ", yend
  # echo xend
  # echo xstep

  for x in arange(xstart..xend, xstep):
    rp.drawLine(x, 0, x, size.height.cint)
  
  for y in arange(ystart..yend, ystep):
    rp.drawLine(0, y, size.width.cint, y)
  
  
  
  # for y in countup(0, self.size.height, self.mGrid.ySpace):
  #   self.sdlRenderer.drawLine(0, y, self.size.width, y)
