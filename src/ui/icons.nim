import std/[os,
            tables]
import wNim
import pixie/fileformats/[png, svg]

type
  IconPaths = Table[string, string]
  IconSVGData = Table[string, string]

proc svgData(paths: IconPaths): IconSVGData =
  for name, path in paths:
    result[name] = path.readFile()

const
  iconsPath = currentSourcePath.parentDir / "icons/svg"
  ext = ".svg"
  iconPaths: IconPaths = 
    [ (name: "align_bottom",     path: iconsPath / "align_bottom"               & ext),
      (name: "align_center",     path: iconsPath / "align_center"               & ext),
      (name: "align_left",       path: iconsPath / "align_left"                 & ext),
      (name: "align_ll_hv",      path: iconsPath / "align_lower_left_hv"        & ext),
      (name: "align_ll_hvarr",   path: iconsPath / "align_lower_left_hv_arrow"  & ext),
      (name: "align_ll_vh",      path: iconsPath / "align_lower_left_vh"        & ext),
      (name: "align_ll_vharr",   path: iconsPath / "align_lower_left_vh_arrow"  & ext),
      (name: "align_lr_hv",      path: iconsPath / "align_lower_right_hv"       & ext),
      (name: "align_lr_hvarr",   path: iconsPath / "align_lower_right_hv_arrow" & ext),
      (name: "align_lr_vh",      path: iconsPath / "align_lower_right_vh"       & ext),
      (name: "align_lr_vharr",   path: iconsPath / "align_lower_right_vh_arrow" & ext),
      (name: "align_mid",        path: iconsPath / "align_mid"                  & ext),
      (name: "align_right",      path: iconsPath / "align_right"                & ext),
      (name: "align_top",        path: iconsPath / "align_top"                  & ext),
      (name: "align_ul_hv",      path: iconsPath / "align_upper_left_hv"        & ext),
      (name: "align_ul_hvarr",   path: iconsPath / "align_upper_left_hv_arrow"  & ext),
      (name: "align_ul_vh",      path: iconsPath / "align_upper_left_vh"        & ext),
      (name: "align_ul_vharr",   path: iconsPath / "align_upper_left_vh_arrow"  & ext),
      (name: "align_ur_hv",      path: iconsPath / "align_upper_right_hv"       & ext),
      (name: "align_ur_hvarr",   path: iconsPath / "align_upper_right_hv_arrow" & ext),
      (name: "align_ur_vh",      path: iconsPath / "align_upper_right_vh"       & ext),
      (name: "align_ur_vharr",   path: iconsPath / "align_upper_right_vh_arrow" & ext),
      (name: "arrow_dn",         path: iconsPath / "arrow_down"                 & ext),
      (name: "arrow_dnleft",     path: iconsPath / "arrow_down_left"            & ext),
      (name: "arrow_dnright",    path: iconsPath / "arrow_down_right"           & ext),
      (name: "arrow_left",       path: iconsPath / "arrow_left"                 & ext),
      (name: "arrow_right",      path: iconsPath / "arrow_right"                & ext),
      (name: "arrow_up",         path: iconsPath / "arrow_up"                   & ext),
      (name: "arrow_upleft",     path: iconsPath / "arrow_up_left"              & ext),
      (name: "arrow_upright",    path: iconsPath / "arrow_up_right"             & ext),
      (name: "close",            path: iconsPath / "close"                      & ext),
      (name: "delete",           path: iconsPath / "delete"                     & ext),
      (name: "done",             path: iconsPath / "done"                       & ext),
      (name: "exit",             path: iconsPath / "exit"                       & ext),
      (name: "file_open",        path: iconsPath / "file_open"                  & ext),
      (name: "folder_open",      path: iconsPath / "folder_open"                & ext),
      (name: "gridonoff",        path: iconsPath / "grid_on_off"                & ext),
      (name: "gridsettings",     path: iconsPath / "grid_settings"              & ext),
      (name: "help",             path: iconsPath / "help"                       & ext),
      (name: "info",             path: iconsPath / "info"                       & ext),
      (name: "move",             path: iconsPath / "move"                       & ext),
      (name: "new_document",     path: iconsPath / "new_document"               & ext),
      (name: "place",            path: iconsPath / "placement"                  & ext),
      (name: "preferences",      path: iconsPath / "preferences"                & ext),
      (name: "resize",           path: iconsPath / "resize"                     & ext),
      (name: "route",            path: iconsPath / "route"                      & ext),
      (name: "save",             path: iconsPath / "save"                       & ext),
      (name: "search",           path: iconsPath / "search"                     & ext),
      (name: "settings",         path: iconsPath / "settings"                   & ext),
      (name: "undo",             path: iconsPath / "undo"                       & ext)].toTable()

when defined(staticIcons):
  const gIconSVGData =  svgData(iconPaths)
else:
  let gIconSVGData = svgData(iconPaths)

proc iconBitmap*(name: string, sz: wSize): wBitmap =
  let sData = gIconSVGData[name]
  let svgObj = parseSvg(sData, sz.width, sz.height)
  let im = newImage(svgObj)
  let pngBytes = im.encodePng()
  let wimg = Image(pngBytes[0].addr, pngBytes.len)
  result = Bitmap(wimg)


when isMainModule:
  echo gIconSVGData