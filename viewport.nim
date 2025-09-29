import std/[math]
import world
import pointmath
export world

type
  ViewPort* = object
    pan*: PxPoint = (0, 0)
    zoom*: float = 1.0
    fakezoom: float = 1.0
    zoomSteps: int

const
  zoomBase = 10 # Eventually this becomes the small grid size
  zoomDiv = 5000 # how many mouse wheels for every power of zoomBase
  zoomMaxPwr = 3 # maximum zoom is zoomBase ^ zoomMaxPwr
  zoomStepUpperLimit =  zoomDiv * zoomMaxPwr # implies max zoom is 2^3
  zoomStepLowerLimit = -zoomDiv * zoomMaxPwr # implies min zoom is 2^-3

proc doZoom*(vp: var ViewPort, delta: int) = 
  # Calculate new zoom factor
  vp.zoomSteps = clamp(vp.zoomSteps + delta,
                       zoomStepLowerLimit,
                       zoomStepUpperLimit)
  vp.fakezoom = pow(zoomBase, vp.zoomSteps / zoomDiv )
  vp.zoom = vp.fakezoom

proc doPan*(vp: var ViewPort, delta: PxPoint) = 
  vp.pan += delta


# Convert from anything to pixels through viewport
# pixel = world * zoom + pan.  Flip zoom for y
proc toPixelX*[T:SomeNumber](x: T, vp: ViewPort): PxType =
  # Implicit conversion to PxType which includes rounding
  (x.float * vp.zoom + vp.pan.x.float)

proc toPixelY*[T:SomeNumber](y: T, vp: ViewPort): PxType =
  # Implicit conversion to PxType which includes rounding
  (y.float * (-vp.zoom) + vp.pan.y.float)

proc toPixel*[T:SomePoint](pt: T, vp: ViewPort): PxPoint =
  (pt[0].toPixelX(vp), pt[1].toPixelY(vp))


# Convert from pixels to world through viewport
# world = (pixel - pan) / zoom.  Flip zoom for y
proc toWorldX*(x: PxType, vp: ViewPort): WType =
  # Implicit conversion to WType which includes rounding if needed
  (x - vp.pan.x).float / vp.zoom

proc toWorldY*(y: PxType, vp: ViewPort): WType =
  (y - vp.pan.y).float / (-vp.zoom)

proc toWorld*[T: SomePoint](pt: T, vp: ViewPort): WPoint =
  (pt[0].toWorldX(vp), pt[1].toWorldY(vp))

proc isPointVisible*(wpt: WPoint, vp: ViewPort, size: PxSize): bool =
  # Returns true if pt is visible on screen
  let pxpt: PxPoint = wpt.toPixel(vp)
  pxpt.x >= 0 and pxpt.x < size.w and
  pxpt.y >= 0 and pxpt.y < size.h



when isMainModule:
  when WType is int:
    let wptx: WType = 10
    let wpty: WType = 10
    let wpt1: WPoint = (wptx, wpty)
    let wpt2: WPoint = (20, 20)
    var vp: ViewPort = ViewPort(pan: (400, 400), zoom: 1.0)
    assert toPixelX(wptx, vp) == 410
    assert toPixelY(wpty, vp) == 390
    assert toPixel(wpt1, vp) == (x: 410, y: 390)
    assert toPixel(wpt2, vp) == (x: 420, y: 380)
    assert toPixel((1.5, 2.0), vp) == (x: 402, y: 398)
    assert toWorld((402, 398), vp) == (2, 2)
    assert wpt1.toPixel(vp).toWorld(vp) == wpt1
    assert wpt2.toPixel(vp).toWorld(vp) == wpt2
    vp.zoom = 1.2
    assert wptx.toPixelX(vp) == 412
    assert wpty.toPixelY(vp) == 388
    assert toPixel(wpt1, vp) == (x: 412, y: 388)
    assert toPixel(wpt2, vp) == (x: 424, y: 376)
    assert toPixel((1.5, 2.0), vp) == (x: 402, y: 398)
    assert toWorld((402, 398), vp) == (2, 2)
    assert wpt1.toPixel(vp).toWorld(vp) == wpt1
    assert wpt2.toPixel(vp).toWorld(vp) == wpt2
    echo "int assertions done"

  elif WType is float:
    let wptx: WType = 10
    let wpty: WType = 10
    let wpt1: WPoint = (wptx, wpty)
    let wpt2: WPoint = (20, 20)
    var vp: ViewPort = ViewPort(pan: (400, 400), zoom: 1.0)
    assert toPixelX(wptx, vp) == 410
    assert toPixelY(wpty, vp) == 390
    assert toPixel(wpt1, vp) == (x: 410, y: 390)
    assert toPixel(wpt2, vp) == (x: 420, y: 380)
    assert toPixel((1.5, 2.0), vp) == (x: 402, y: 398)
    assert toWorld((402, 398), vp) == (x: 2.0, y: 2.0)
    assert wpt1.toPixel(vp).toWorld(vp) == wpt1
    assert wpt2.toPixel(vp).toWorld(vp) == wpt2
    vp.zoom = 1.2
    assert wptx.toPixelX(vp) == 412
    assert wpty.toPixelY(vp) == 388
    assert toPixel(wpt1, vp) == (x: 412, y: 388)
    assert toPixel(wpt2, vp) == (x: 424, y: 376)
    assert toPixel((1.5, 2.0), vp) == (x: 402, y: 398)
    assert toWorld((402, 398), vp) == (x: 1.6667, y: 1.6667)
    assert wpt1.toPixel(vp).toWorld(vp) == wpt1
    assert wpt2.toPixel(vp).toWorld(vp) == wpt2
    echo "float assertions done"
