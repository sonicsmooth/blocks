import std/math
import world
import pointmath
export world


type
  ViewPort* = object
    pan*: PxPoint = (0, 0)
    zClicks*: int # counts wheel zClicks; there are div zClicks between levels
    rawZoom*: float # zoom before density applied
    zoom*: float # final zoom value after density
    zctrl*: ZoomCtrl

  ZoomCtrl = object
    base*: int = 5 # Eventually this becomes the small grid size
    clickDiv*: int = 2400 # how many zClicks for every power of zoomBase (log)
    maxPwr: int = 5 # maximum rawZoom is zoomBase ^ maxPwr
    density*: float = 2.0 # scales entire image without affecting grid
    logStep*: int # each log controls the big and small grid


proc doPan*(vp: var ViewPort, delta: PxPoint) = 
  # Just pan by the pixel amount
  vp.pan += delta

proc doZoom*(vp: var ViewPort, delta: int) = 
  # Calculate new zoom factor
  let
    maxzClicks =  vp.zctrl.clickDiv * vp.zctrl.maxPwr
  vp.zClicks = clamp(vp.zClicks + delta, -maxzClicks, maxzClicks)
  vp.rawZoom = pow(vp.zctrl.base.float, vp.zClicks / vp.zctrl.clickDiv )
  vp.zoom = vp.rawZoom * vp.zctrl.density
  vp.zctrl.logStep = (vp.zClicks / vp.zctrl.clickDiv).floor.int


proc doAdaptivePan*(vp1, vp2: ViewPort, mousePos: PxPoint): PxPoint =
  # Keep mouse location in the same spot during zoom.
  # Mouse position is the same before and after because it's just the wheel event
  # We want world position to be the same so it looks like things aren't moving
  # Set world1 = world2 = (mp-p1)/z1 = (mp-p2)/z2
  # Solve for p2 = mp-(mp-p1)*(z2/z1)
  # pan delta = p2-p1 = mp(1-zr) + p1(zr-1) where mp is mousePos in pixels
  # and zr is ratio of zooms after/before
  let
    pan = vp1.pan
    zr = vp2.zoom / vp1.zoom
  (x: (mousePos.x.float * (1.0 - zr)) + (pan.x.float * (zr - 1.0)),
   y: (mousePos.y.float * (1.0 - zr)) + (pan.y.float * (zr - 1.0)))


# Convert from anything to pixels through viewport
# pixel = world * zoom + pan.  Flip zoom for y
proc toPixelX*[T:SomeNumber](x: T, vp: ViewPort): PxType =
  # Implicit conversion to PxType which includes rounding
  (x.float * vp.zoom + vp.pan.x.float)

proc toPixelY*[T:SomeNumber](y: T, vp: ViewPort): PxType =
  # Implicit conversion to PxType which includes rounding
  (y.float * (-vp.zoom) + vp.pan.y.float) # add extra to offset down by 1

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
