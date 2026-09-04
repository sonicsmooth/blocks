import std/[os, tables]
import wNim
import pixie/fileformats/[png, svg]

type
  IconState* = enum isNormal, isHover, isPressed
  IconVariants = array[IconState, string]   # SVG content per state
  IconTable = Table[string, IconVariants]

const
  iconsPath = currentSourcePath.parentDir / "icons/svg"
  ext = ".svg"
  suffixFor: array[IconState, string] = ["", "_hover", "_pressed"]

  baseNames = [
    ("align_bottom",    "align_bottom"),
    ("align_center",    "align_center"),
    ("align_left",      "align_left"),
    ("align_ll_hv",     "align_lower_left_hv"),
    ("align_ll_hvarr",  "align_lower_left_hv_arrow"),
    ("align_ll_vh",     "align_lower_left_vh"),
    ("align_ll_vharr",  "align_lower_left_vh_arrow"),
    ("align_lr_hv",     "align_lower_right_hv"),
    ("align_lr_hvarr",  "align_lower_right_hv_arrow"),
    ("align_lr_vh",     "align_lower_right_vh"),
    ("align_lr_vharr",  "align_lower_right_vh_arrow"),
    ("align_mid",       "align_mid"),
    ("align_right",     "align_right"),
    ("align_top",       "align_top"),
    ("align_ul_hv",     "align_upper_left_hv"),
    ("align_ul_hvarr",  "align_upper_left_hv_arrow"),
    ("align_ul_vh",     "align_upper_left_vh"),
    ("align_ul_vharr",  "align_upper_left_vh_arrow"),
    ("align_ur_hv",     "align_upper_right_hv"),
    ("align_ur_hvarr",  "align_upper_right_hv_arrow"),
    ("align_ur_vh",     "align_upper_right_vh"),
    ("align_ur_vharr",  "align_upper_right_vh_arrow"),
    ("arrow_down",      "arrow_down"),
    ("arrow_downleft",  "arrow_down_left"),
    ("arrow_downright", "arrow_down_right"),
    ("arrow_left",      "arrow_left"),
    ("arrow_right",     "arrow_right"),
    ("arrow_up",        "arrow_up"),
    ("arrow_upleft",    "arrow_up_left"),
    ("arrow_upright",   "arrow_up_right"),
    ("close",           "close"),
    ("delete",          "delete"),
    ("done",            "done"),
    ("drag",            "drag"),
    ("draw_region",     "draw_region"),
    ("exit",            "exit"),
    ("file_open",       "file_open"),
    ("folder_open",     "folder_open"),
    ("gridonoff",       "grid_on_off"),
    ("gridsettings",    "grid_settings"),
    ("help",            "help"),
    ("info",            "info"),
    ("move",            "move"),
    ("new_document",    "new_document"),
    ("place",           "placement"),
    ("preferences",     "preferences"),
    ("route",           "route"),
    ("save",            "save"),
    ("search",          "search"),
    ("settings",        "settings"),
    ("stop",            "stop"),
    ("undo",            "undo"),
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
      result.variants[state] = result.variants[isNormal]

proc buildIconTable(): IconTable =
  for (key, baseFile) in baseNames:
    let (variants, _) = loadVariants(baseFile)
    result[key] = variants

when defined(staticIcons):
  const gIcons = buildIconTable()
else:
  let gIcons = buildIconTable()

proc iconNames*(): seq[string] =
  for name in gIcons.keys:
    result.add(name)

proc iconBitmap*(name: string, sz: wSize, state: IconState = isNormal): wBitmap =
  if name notin gIcons:
    raise newException(KeyError, "Unknown icon name: '" & name & "'. Known: " & $iconNames())
  let sData = gIcons[name][state]
  let svgObj = parseSvg(sData, sz.width, sz.height)
  let im = newImage(svgObj)
  let pngBytes = im.encodePng()
  let wimg = Image(pngBytes[0].addr, pngBytes.len)
  result = Bitmap(wimg)

when isMainModule:
  echo "Loaded ", iconNames().len, " icons:"
  var anyMissing = false
  for (key, baseFile) in baseNames:
    let (_, missing) = loadVariants(baseFile)
    if missing.len > 0:
      anyMissing = true
      echo "  ", key, " -- missing: ", missing
  if not anyMissing:
    echo "  (no missing states)"