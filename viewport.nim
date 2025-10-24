import std/math
import appinit
import world
import pointmath
export world


type
  ZoomCtrl* = ref object
    base*:     int   # Base of zoom and minor grid size
    clickDiv*: int   # how many zClicks for every power of zoomBase (log)
    maxPwr:    int   # maximum rawZoom is base ^ maxPwr
    density*:  float # scales entire image without affecting grid
    logStep*:  int   # each log controls the big and small grid

  Viewport* = ref object
    # These are controlled by user
    pan*:     PxPoint #= (0, 0)
    zClicks*: int   #= 0 # counts wheel zClicks; there are div zClicks between levels
    zctrl*:   ZoomCtrl
    # These are calculated at runtime
    rawZoom*: float #= 1.0 # zoom before density applied
    zoom*:    float #= 1.0 # final zoom value after density

proc newZoomCtrl*(base, clickDiv, maxPwr: int, density: float): ZoomCtrl =
  # Values in json file override arg values
  # The "to" macro doesn't work because the logStep field is
  # not included in the json.  The logStep value is calculated
  # at runtime, so it shouldn't be specified in the json file.
  let j = gViewportJ["zctrl"]
  result = new ZoomCtrl
  result.base     = if j.contains("base"): j["base"].getInt      else: base
  result.clickDiv = if j.contains("clickDiv"): j["clickDiv"].getInt  else: clickDiv
  result.maxPwr   = if j.contains("maxPwr"): j["maxPwr"].getInt    else: maxPwr
  result.density  = if j.contains("density"): j["density"].getFloat else: density
  # logstep is calculated by doZoom

proc doZoom*(vp: var Viewport, delta: int)
proc newViewport*(pan: PxPoint, clicks: int, zCtrl: ZoomCtrl): Viewport =
  # Values in json file override arg values except zctrl
  # zctrl must be passed already properly formed by caller
  let j = gViewportJ
  result = new Viewport
  result.pan = if j.contains("pan"): j["pan"].getPxPoint else: pan
  result.zClicks = if j.contains("zClicks"): j["zClicks"].getInt else: clicks
  result.zctrl = zCtrl
  # The doZoom call updates values in result, including result.zctrl.
  doZoom(result, 0) 

proc doPan*(vp: var Viewport, delta: PxPoint) = 
  # Just pan by the pixel amount
  vp.pan += delta

proc doZoom*(vp: var Viewport, delta: int) = 
  # Calculate new zoom factor
  # inputs to calc: pan, zclicks, zctrl
  # outputs from calc: rawZoom, zoom
  let
    maxzClicks =  vp.zctrl.clickDiv * vp.zctrl.maxPwr
  vp.zClicks = clamp(vp.zClicks + delta, -maxzClicks, maxzClicks)
  vp.rawZoom = pow(vp.zctrl.base.float, vp.zClicks / vp.zctrl.clickDiv )
  vp.zoom = vp.rawZoom * vp.zctrl.density
  vp.zctrl.logStep = (vp.zClicks / vp.zctrl.clickDiv).floor.int

proc doAdaptivePan*(vp1, vp2: Viewport, mousePos: PxPoint): PxPoint =
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
proc toPixelX*[T:SomeNumber](x: T, vp: Viewport): PxType =
  # Implicit conversion to PxType which includes rounding
  (x.float * vp.zoom + vp.pan.x.float)

proc toPixelY*[T:SomeNumber](y: T, vp: Viewport): PxType =
  # Implicit conversion to PxType which includes rounding
  (y.float * (-vp.zoom) + vp.pan.y.float) # add extra to offset down by 1

proc toPixel*[T:SomePoint](pt: T, vp: Viewport): PxPoint =
  (pt[0].toPixelX(vp), pt[1].toPixelY(vp))


# Convert from pixels to world through viewport
# world = (pixel - pan) / zoom.  Flip zoom for y
proc toWorldX*(x: PxType, vp: Viewport): WType =
  # Implicit conversion to WType which includes rounding if needed
  (x - vp.pan.x).float / vp.zoom

proc toWorldY*(y: PxType, vp: Viewport): WType =
  (y - vp.pan.y).float / (-vp.zoom)

proc toWorld*[T: SomePoint](pt: T, vp: Viewport): WPoint =
  (pt[0].toWorldX(vp), pt[1].toWorldY(vp))

proc isPointVisible*(wpt: WPoint, vp: Viewport, size: PxSize): bool =
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
    var vp: Viewport = Viewport(pan: (400, 400), zoom: 1.0)
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
    var vp: Viewport = Viewport(pan: (400, 400), zoom: 1.0)
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
