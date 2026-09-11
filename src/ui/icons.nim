import std/[os, tables]
import wNim
import pixie/fileformats/[svg]

type
  IconState* = enum Normal, Hover, Pressed
  IconVariants = array[IconState, string]   # SVG content per state
  IconTable = Table[string, IconVariants]
  BitmapKey = tuple[name: string, size: wSize, state: IconState]
  BitmapCache = Table[BitmapKey, wTypes.wBitmap]  # Cache of rendered bitmaps

const
  iconsPath = currentSourcePath.parentDir / "icons/svg"
  ext = ".svg"
  suffixFor: array[IconState, string] = ["", "_hover", "_pressed"]

  baseNames = [
    ("align_bottom",         "align_bottom"),
    ("align_center",         "align_center"),
    ("align_left",           "align_left"),
    ("lower_left_hv",        "lower_left_hv"),
    ("lower_left_hv_arrow",  "lower_left_hv_arrow"),
    ("lower_left_vh",        "lower_left_vh"),
    ("lower_left_vh_arrow",  "lower_left_vh_arrow"),
    ("lower_right_hv",       "lower_right_hv"),
    ("lower_right_hv_arrow", "lower_right_hv_arrow"),
    ("lower_right_vh",       "lower_right_vh"),
    ("lower_right_vh_arrow", "lower_right_vh_arrow"),
    ("align_mid",            "align_mid"),
    ("align_right",          "align_right"),
    ("align_top",            "align_top"),
    ("upper_left_hv",        "upper_left_hv"),
    ("upper_left_hv_arrow",  "upper_left_hv_arrow"),
    ("upper_left_vh",        "upper_left_vh"),
    ("upper_left_vh_arrow",  "upper_left_vh_arrow"),
    ("upper_right_hv",       "upper_right_hv"),
    ("upper_right_hv_arrow", "upper_right_hv_arrow"),
    ("upper_right_vh",       "upper_right_vh"),
    ("upper_right_vh_arrow", "upper_right_vh_arrow"),
    ("arrow_down",           "arrow_down"),
    ("arrow_downleft",       "arrow_down_left"),
    ("arrow_downright",      "arrow_down_right"),
    ("arrow_left",           "arrow_left"),
    ("arrow_right",          "arrow_right"),
    ("arrow_up",             "arrow_up"),
    ("arrow_upleft",         "arrow_up_left"),
    ("arrow_upright",        "arrow_up_right"),
    ("close",                "close"),
    ("delete",               "delete"),
    ("done",                 "done"),
    ("drag",                 "drag"),
    ("draw_region",          "draw_region"),
    ("exit",                 "exit"),
    ("file_open",            "file_open"),
    ("folder_open",          "folder_open"),
    ("gridonoff",            "grid_on_off"),
    ("gridsettings",         "grid_settings"),
    ("help",                 "help"),
    ("info",                 "info"),
    ("move",                 "move"),
    ("new_document",         "new_document"),
    ("place",                "placement"),
    ("preferences",          "preferences"),
    ("route",                "route"),
    ("save",                 "save"),
    ("search",               "search"),
    ("settings",             "settings"),
    ("stop",                 "stop"),
    ("undo",                 "undo"),
  ]


proc loadVariants(baseFile: string): tuple[variants: IconVariants, missing: seq[IconState]] =
  # Load whichever state files actually exist; record which ones don't.
  for state in IconState:
    let p = iconsPath / (baseFile & suffixFor[state] & ext)
    if fileExists(p):
      result.variants[state] = p.readFile()
    else:
      result.missing.add(state)
  # Fall back any missing variant to the normal state so callers always
  # get a usable bitmap, even if it's visually identical across states.
  for state in IconState:
    if result.variants[state].len == 0:
      result.variants[state] = result.variants[Normal]

proc buildIconTable(): IconTable =
  for (key, baseFile) in baseNames:
    let (variants, _) = loadVariants(baseFile)
    result[key] = variants

when defined(staticIcons):
  const gIcons: IconTable = buildIconTable()
else:
  let gIcons: IconTable = buildIconTable()
var gBitmapCache: BitmapCache


proc renderBitmap(svgData: string, sz: wSize): wBitmap =
  let svgObj = parseSvg(svgData, sz.width, sz.height)
  let im = newImage(svgObj)
  for i in 0 ..< im.data.len:
    swap(im.data[i].r, im.data[i].b)
  let wimg = Image(im.width, im.height, im.width * 4,
                   wPixelFormat32bppPARGB, im.data[0].addr)
  Bitmap(wimg)

proc initIconBitmaps*(name: string, size: wSize) =
  # Render and cache specific bitmap to given size, for all states
  if name notin gIcons:
    raise newException(KeyError, "Unknown icon name: '" & name & "'.")
  for state, svg in gIcons[name]:
    if (name, size, state) notin gBitmapCache:
      # echo "rendering/caching ", name, " ", state, " ", size
      gBitmapCache[(name, size, state)] = renderBitmap(svg, size)

proc initIconBitmaps*(name: string, sizes: openArray[wSize]) =
  # TODO: multithread
  for size in sizes:
    initIconBitmaps(name, size)

proc initIconBitmaps*(names: openArray[string], size: wSize) =
  # Render and cache all given names at given size
  # TODO: multithreaded
  for name in names:
    initIconBitmaps(name, size)

proc initIconBitmaps*(names: openArray[string], sizes: openArray[wSize]) =
  # Render and cache all given names at all given sizes
  # TODO: multithreaded
  for name in names:
    for sz in sizes:
      initIconBitmaps(name, sz)

proc initIconBitmaps*(sz: wSize) =
  # Prime all bitmaps to given size, for all states
  # TODO: multithreaded
  for name, _ in gIcons:
    initIconBitmaps(name, sz)

proc initIconBitmaps*(sizes: openArray[wSize]) =
  # Prime all bitmaps to given sizes, for all states
  # TODO: multithreaded
  var names: seq[string]
  for name, _ in gIcons:
    names.add(name)
  initIconBitmaps(names, sizes)


proc iconNames*(): seq[string] =
  for name in gIcons.keys:
    result.add(name)

proc iconBitmap*(name: string, sz: wSize, state: IconState = Normal): wBitmap =
  # Load a bitmap from cache if available, else render fresh, cache, and return
  if name notin gIcons:
    raise newException(KeyError, "Unknown icon name: '" & name & "'.")
  if (name, sz, state) notin gBitmapCache:
    echo "cache miss for icon '", name, "' state ", state, " with size ", sz
    let svg = gIcons[name][state]
    gBitmapCache[(name, sz, state)] = renderBitmap(svg, sz)
  gBitmapCache[(name, sz, state)]

when isMainModule:
  import monoprofile
  echo "Loaded ", iconNames().len, " icons:"
  var anyMissing = false
  for (key, baseFile) in baseNames:
    let (_, missing) = loadVariants(baseFile)
    if missing.len > 0:
      anyMissing = true
      echo "  ", key, " -- missing: ", missing
  if not anyMissing:
    echo "  (no missing states)"
  
  # Test rendering
  echo "caching stop at 24, normal only, reporting size"
  timeItms(iconProfile, "normal, 24"):
    echo renderBitmap(gIcons["stop"][Normal], (24, 24)).size

  echo "caching stop at 24"
  timeItms(iconProfile, "time: "):
    initIconBitmaps("stop", (24, 24))
  gBitmapCache.clear()

  echo "caching done at 16, 24"
  timeItms(iconProfile, "time: "):
    initIconBitmaps("done", [(16, 16), (24, 24)])
  gBitmapCache.clear()

  echo "caching close, drag at 16"
  timeItms(iconProfile, "time: "):
    initIconBitmaps(["close", "drag"], (16, 16))
  gBitmapCache.clear()
  
  echo "caching delete, help at 16, 24"
  timeItms(iconProfile, "time: "):
    initIconBitmaps(["delete", "help"], [(16, 16), (24, 24)])
  gBitmapCache.clear()

  echo "caching all at 16"
  timeItms(iconProfile, "time: "):
    initIconBitmaps((16, 16))
  gBitmapCache.clear()

  echo "caching all at 16, 24"
  timeItms(iconProfile, "time: "):
    initIconBitmaps([(16, 16), (24, 24)])
  gBitmapCache.clear()

  
