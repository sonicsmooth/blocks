import std/[math, strformat]
import appinit
import world
import pointmath
export world

# TODO: allow user to set zoom level directly,
# then proc determines closest clicks value.
# User should be able to re-achieve the same zoom
# level after going up and down, which means
# extreme click limits may not be reached, or may
# be exceeded.  If the user's requested zoom
# level doesn't allow an integer click value, then
# zoom value is still respected, but the ZoomCtrl
# is "inconsistent", which means the zoom level
# will be re-reached if the user zooms up and down

type
  ZoomCtrl* = ref object
    mBase:     int   # Base of zoom and minor grid size
    mClickDiv: int   # how many zClicks for every power of zoomBase (log)
    mMaxPwr:   int   # maximum rawZoom is base ^ maxPwr
    mDensity:  float # scales entire image without affecting grid
    mLogStep:  int   # each log controls the big and small grid

  Viewport* = ref object
    # These are controlled by user
    mPan*:     PxPoint #= (0, 0)
    mZclicks*: float   #= 0 # counts wheel zClicks; there are div zClicks between levels
    mZctrl*:   ZoomCtrl
    # These are calculated at runtime
    mRawZoom*: float #= 1.0 # zoom before density applied
    mZoom*:    float #= 1.0 # final zoom value after density

proc base*(zctrl: ZoomCtrl): int =  zctrl.mBase
# Only change base through grid.setDivisions!!
proc `base=`*(zctrl: ZoomCtrl, val: int) = 
  let oldbase = zctrl.base
  zctrl.mBase = val
  echo &"base changing {oldbase} -> {zctrl.base}"
proc clickDiv*(zctrl: ZoomCtrl): int =  zctrl.mClickDiv
proc maxPwr*(zctrl: ZoomCtrl): int =  zctrl.mMaxPwr
proc density*(zctrl: ZoomCtrl): float =  zctrl.mDensity
proc logStep*(zctrl: ZoomCtrl): int =  zctrl.mLogStep

# TODO: Move ZoomCtrl to another file
proc newZoomCtrl*(): ZoomCtrl =
  # Fill values from from json
  # The "to" macro doesn't work because the logStep field is
  # not included in the json.  The logStep value is calculated
  # at runtime, so it shouldn't be specified in the json file.
  result = new ZoomCtrl
  result.mBase     = gZctrlJ["base"].getInt
  result.mClickDiv = gZctrlJ["clickDiv"].getInt
  result.mMaxPwr   = gZctrlJ["maxPwr"].getInt
  result.mDensity  = gZctrlJ["density"].getFloat

proc newZoomCtrl*(base, clickDiv, maxPwr: int, density: float): ZoomCtrl =
  # Fill values from args
  # logstep is calculated by doZoom
  result = new ZoomCtrl
  result.mBase     = base
  result.mClickDiv = clickDiv
  result.mMaxPwr   = maxPwr
  result.mDensity  = density

# forward decl
proc doZoom*(vp: var Viewport, delta: int)

proc pan*(vp: Viewport): PxPoint = vp.mPan
proc zClicks*(vp: Viewport): float = vp.mZclicks
proc zCtrl*(vp: Viewport): ZoomCtrl = vp.mZctrl
proc rawZoom*(vp: Viewport): float = vp.mRawZoom
proc zoom*(vp: Viewport): float = vp.mZoom
proc `zoom=`*(vp: var Viewport, val: float) =
  # Forcibly set zoom to new value by solving for Zclicks
  # Starting with rawZoom = base ^ (Zclicks / ClickDiv)
  # -> log(rawzoom [base]) = Zclicks / clickDiv
  # -> zclicks = log(rawZoom [base]) * clickDiv
  let newClicks = log(val, vp.zctrl.base.float) * vp.zctrl.clickDiv.float
  vp.mZclicks = newClicks
  vp.doZoom(0)


proc newViewport*(): Viewport = 
  # Fill in values from json
  # zctrl must be passed already properly formed by caller
  # The doZoom call updates values in result, including result.zctrl.
  let j = gViewportJ
  result = new Viewport
  result.mPan = j["pan"].toPxPoint
  result.mZclicks = j["zClicks"].getFloat
  result.mZctrl = newZoomCtrl()
  doZoom(result, 0) 

proc newViewport*(pan: PxPoint, clicks: float, zCtrl: ZoomCtrl): Viewport =
  # Fill in values from args
  # zctrl must be passed already properly formed by caller
  result = new Viewport
  result.mPan = pan
  result.mZclicks = clicks
  result.mZctrl = zCtrl
  # The doZoom call updates values in result, including result.zctrl.
  doZoom(result, 0) 

proc doPan*(vp: var Viewport, delta: PxPoint) = 
  # Just pan by the pixel amount
  vp.mPan += delta

proc doZoom*(vp: var Viewport, delta: int) = 
  # Calculate new zoom factor
  # inputs to calc: pan, zclicks, zctrl
  # outputs from calc: rawZoom, zoom
  let
    maxzClicks =  vp.mZctrl.clickDiv * vp.mZctrl.maxPwr
  vp.mZclicks = clamp(vp.mZclicks + delta.float, -maxzClicks.float, maxzClicks.float)
  vp.mRawZoom = pow(vp.mZctrl.mBase.float, vp.mZclicks / vp.mZctrl.mClickDiv )
  vp.mZoom = vp.mRawZoom * vp.mZctrl.density
  vp.mZctrl.mLogStep = (vp.mZclicks / vp.mZctrl.mClickDiv).floor.int

proc doAdaptivePanZoom*(vp: var Viewport, zoomClicks: int, mousePos: PxPoint) =
  # Keep mouse location in the same spot during zoom.
  # Mouse position is the same before and after because it's just the wheel event
  # We want world position to be the same so it looks like things aren't moving
  # Set world1 = world2 = (mp-p1)/z1 = (mp-p2)/z2
  # Solve for p2 = mp-(mp-p1)*(z2/z1)
  # pan delta = p2-p1 = mp(1-zr) + p1(zr-1) where mp is mousePos in pixels
  # and zr is ratio of zooms after/before
  let
    vp1 = vp[] # make a local copy because Viewport is a reference type
    pan = vp1.mPan
  vp.doZoom(zoomClicks)
  let zr = vp.mZoom / vp1.mZoom
  # Should convert to PxPoint implicitly
  vp.doPan((x: (mousePos.x.float * (1.0 - zr)) + (pan.x.float * (zr - 1.0)),
            y: (mousePos.y.float * (1.0 - zr)) + (pan.y.float * (zr - 1.0))))


# Convert from anything to pixels through viewport
# pixel = world * zoom + pan.  Flip zoom for y
proc toPixelX*[T:SomeNumber](x: T, vp: Viewport): PxType =
  # Implicit conversion to PxType which includes rounding
  (x.float * vp.mZoom + vp.mPan.x.float)

proc toPixelY*[T:SomeNumber](y: T, vp: Viewport): PxType =
  # Implicit conversion to PxType which includes rounding
  (y.float * (-vp.mZoom) + vp.mPan.y.float)

proc toPixel*[T:SomePoint](pt: T, vp: Viewport): PxPoint =
  (pt[0].toPixelX(vp), pt[1].toPixelY(vp))


# Convert from pixels to world through viewport
# world = (pixel - pan) / zoom.  Flip zoom for y
proc toWorldX*(x: PxType, vp: Viewport): WType =
  # Implicit conversion to WType which includes rounding if needed
  (x - vp.mPan.x).float / vp.mZoom

proc toWorldY*(y: PxType, vp: Viewport): WType =
  (y - vp.mPan.y).float / (-vp.mZoom)

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
    let zc: ZoomCtrl = newZoomCtrl()
    var vp: Viewport = newViewport(pan=(400,400), clicks=0, zc)
    assert toPixelX(wptx, vp) == 410
    assert toPixelY(wpty, vp) == 390
    assert toPixel(wpt1, vp) == (x: 410, y: 390)
    assert toPixel(wpt2, vp) == (x: 420, y: 380)
    assert toPixel((1.5, 2.0), vp) == (x: 402, y: 398)
    assert toWorld((402, 398), vp) == (2, 2)
    assert wpt1.toPixel(vp).toWorld(vp) == wpt1
    assert wpt2.toPixel(vp).toWorld(vp) == wpt2
    vp.mZoom = 1.2
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
