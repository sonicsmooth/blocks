import std/[math]
import sdl2
import world
export world

type
  ViewPort* = object
    pan*: sdl2.Point = (0, 0)
    zoom*: float = 1.0

# Proc args are provided as both vp,coord and coord,vp
# so you can do point.toWhatever(vp) and also vp.toWhatever(point)

# pixel = world * zoom + pan.  Flip zoom for y
proc toPixelX*(vp: ViewPort, x: world.WCoordT): cint =
  (x.float * vp.zoom + vp.pan.x.float).round.cint
proc toPixelX*(x: world.WCoordT, vp: ViewPort): cint =
  (x.float * vp.zoom + vp.pan.x.float).round.cint
proc toPixelY*(vp: ViewPort, y: world.WCoordT): cint =
  (y.float * (-vp.zoom) + vp.pan.y.float).round.cint
proc toPixelY*(y: world.WCoordT, vp: ViewPort): cint =
  (y.float * (-vp.zoom) + vp.pan.y.float).round.cint
proc toPixel*(vp: ViewPort, pt: WPoint): sdl2.Point =
  let
    newx = pt.x.float *   vp.zoom  + vp.pan.x.float
    newy = pt.y.float * (-vp.zoom) + vp.pan.y.float
  (newx.round.cint, newy.round.cint)
proc toPixel*(pt: WPoint, vp: ViewPort): sdl2.Point =
  let
    newx = pt.x.float *   vp.zoom  + vp.pan.x.float
    newy = pt.y.float * (-vp.zoom) + vp.pan.y.float
  (newx.round.cint, newy.round.cint)




# world = (pixel - pan) / zoom.  Flip zoom for y
# pixels are always integers
proc toWorld*(vp: ViewPort, pt: tuple[x, y: SomeInteger]): WPoint =
  let
    newpt = pt.toWorldPoint
    newpan = vp.pan.toWorldPoint
    newxf = (newpt.x - newpan.x).float /   vp.zoom
    newyf = (newpt.y - newpan.y).float / (-vp.zoom)
  result = WPoint((newxf, newyf))
proc toWorld*(pt: tuple[x, y: SomeInteger], vp: ViewPort): WPoint =
  let newpt = pt.toWorldPoint
  let newpan = vp.pan.toWorldPoint
  let newxf = (newpt.x - newpan.x).float /   vp.zoom
  let newyf = (newpt.y - newpan.y).float / (-vp.zoom)
  result = WPoint((newxf, newyf))

proc toWorldX*(vp: ViewPort, x: SomeInteger): world.WCoordT =
  let
    newptX = x.toWorldCoord
    newpanX = vp.pan.x.toWorldCoord
    newxf = (newptX - newpanX).float / vp.zoom
  result = world.WCoordT(newxf)
proc toWorldX*(x: SomeInteger, vp: ViewPort): world.WCoordT =
  let
    newptX = x.toWorldCoord
    newpanX = vp.pan.x.toWorldCoord
    newxf = (newptX - newpanX).float / vp.zoom
  result = world.WCoordT(newxf)

proc toWorldY*(vp: ViewPort, y: SomeInteger): world.WCoordT =
  let
    newptY = y.toWorldCoord
    newpanY = vp.pan.y.toWorldCoord
    newyf = (newptY - newpanY).float / (-vp.zoom)
  result = world.WCoordT(newyf)
proc toWorldY*(y: SomeInteger, vp: ViewPort): world.WCoordT =
  let
    newptY = y.toWorldCoord
    newpanY = vp.pan.y.toWorldCoord
    newyf = (newptY - newpanY).float / (-vp.zoom)
  result = world.WCoordT(newyf)

when isMainModule:
  let vp = ViewPort(pan: (400, 400), zoom: 1.0)
  let p1 = (10,10).WPoint
  assert p1.toPixel(vp).toWorld(vp) == p1