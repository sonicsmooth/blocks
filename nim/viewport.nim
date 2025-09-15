import std/math
import sdl2
import world

type
  ViewPort* = object
    pan*: sdl2.Point
    zoom*: float

# pixel = world * zoom + pan.  Flip zoom for y
proc toPixelX*(vp: ViewPort, x: world.CoordT): cint =
  (x.float * vp.zoom + vp.pan.x.float).round.cint
proc toPixelY*(vp: ViewPort, y: world.CoordT): cint =
  (y.float * (-vp.zoom) + vp.pan.y.float).round.cint
proc toPixel*(vp: ViewPort, pt: world.Point): sdl2.Point =
  let
    newx = pt.x.float *   vp.zoom  + vp.pan.x.float
    newy = pt.y.float * (-vp.zoom) + vp.pan.y.float
  (newx.round.cint, newy.round.cint)




# world = (pixel - pan) / zoom.  Flip zoom for y
proc toWorld*(vp: ViewPort, pt: sdl2.Point): world.Point =
  let
    newpt = pt.toWorldPoint
    newpan = vp.pan.toWorldPoint
    newxf = (newpt.x - newpan.x).float /   vp.zoom
    newyf = (newpt.y - newpan.y).float / (-vp.zoom)
  result = world.Point((newxf, newyf))

proc toWorldX*(vp: ViewPort, x: cint): world.CoordT =
  let
    newptX = x.toWorldCoord
    newpanX = vp.pan.x.toWorldCoord
    newxf = (newptX - newpanX).float / vp.zoom
  result = world.CoordT(newxf)

proc toWorldY*(vp: ViewPort, y: cint): world.CoordT =
  let
    newptY = y.toWorldCoord
    newpanY = vp.pan.y.toWorldCoord
    newyf = (newptY - newpanY).float / (-vp.zoom)
  result = world.CoordT(newyf)

