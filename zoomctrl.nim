from std/math import floor
import appinit


type
  ZoomCtrl* = ref object
    mBase:     int   # Base of zoom and minor grid size
    mClickDiv: int   # how many zClicks for every power of zoomBase (log)
    mMaxPwr:   int   # maximum rawZoom is base ^ maxPwr
    mDensity:  float # scales entire image without affecting grid
    mLogStep:  int   # each log controls the big and small grid
    mDynamic:  bool  # Whether the grids change scale
    mBaseSync: bool  # Whether the base is synced to divisions

proc base*(zctrl: ZoomCtrl): int =  zctrl.mBase
proc clickDiv*(zctrl: ZoomCtrl): int = zctrl.mClickDiv
proc maxPwr*(zctrl: ZoomCtrl): int = zctrl.mMaxPwr
proc density*(zctrl: ZoomCtrl): float = zctrl.mDensity
proc logStep*(zctrl: ZoomCtrl): int = zctrl.mLogStep
proc dynamic*(zctrl: ZoomCtrl): bool = zctrl.mDynamic
proc baseSync*(zctrl: ZoomCtrl): bool = zctrl.mBaseSync
# Only change base from grid.divisions= or grid.updateBase
proc `base=`*(zctrl: ZoomCtrl, val: int) = zctrl.mBase = val
proc `clickDiv=`*(zctrl: var ZoomCtrl, val: int) = zctrl.mClickDiv = val
proc `maxPwr=`*(zctrl: var ZoomCtrl, val: int) = zctrl.mMaxPwr = val
proc `density=`*(zctrl: var ZoomCtrl, val: float) = zctrl.mDensity = val
# Only change logStep from viewport.doZoom
proc updateLogStep*(zctrl: var ZoomCtrl, zclicks: float) = 
  zctrl.mLogStep = (zclicks / zctrl.mClickDiv.float).floor.int
proc `dynamic=`*(zctrl: var ZoomCtrl, val: bool) = zctrl.mDynamic = val
proc `baseSync=`*(zctrl: var ZoomCtrl, val: bool) =
  # If val is true be sure to call grid.updateBase afterwards
  zctrl.mBaseSync = val

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
  result.mDynamic  = gZctrlJ["dynamic"].getBool

proc newZoomCtrl*(base, clickDiv, maxPwr: int, density: float): ZoomCtrl =
  # Fill values from args
  # logstep is calculated by doZoom
  result = new ZoomCtrl
  result.mBase     = base
  result.mClickDiv = clickDiv
  result.mMaxPwr   = maxPwr
  result.mDensity  = density
