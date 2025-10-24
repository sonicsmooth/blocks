import std/[os, parseopt, strutils, strformat]
import appinit

type
  AppOpts* = ref object
    appHelp*: bool = false
    enableBbox*: bool = false # calc and show
    enableDstRect*: bool = false # show (calc always anyway)
    enableText*: bool = true
    enableHover*: bool = true
    compQty*: int = 1

## GLOBAL VAR FOR USE EVERYWHERE
## TODO: Do something here with the .json file
## To load up defaults which can be overridden by
## cmd line args
var
  gAppOpts*: AppOpts

proc showAppHelp*(opts: AppOpts) =
  let afn = getAppFilename().splitPath.tail
  echo &"Usage: {afn} [options]"
  echo "  -h, --help:   show this help"
  echo "  --bbox:       calculate and show bounding box"
  echo "  --dstrect:    show compact destination rectangle"
  echo "  --notext:     don't show component ID"
  echo "  --nohover:    disable hovering behavior"
  echo "  -q=N, --qty=N: create N random components."
  echo "\n  Current values:"
  for k,v in opts[].fieldPairs:
    echo "    ", k, " = ", v

proc parseAppOptions*(): AppOpts = 
  #result = AppOpts()
  # Start with values in json file, then override 
  # with command line values
  result = gAppOptsJ.to(AppOpts)
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      discard
    of cmdLongOption, cmdShortOption:
      case key:
      of "help", "h": result.appHelp = true
      of "bbox": result.enableBbox = true
      of "dstrect": result.enableDstRect = true
      of "notext": result.enableText = false
      of "nohover": result.enableHover = false
      of "qty", "q": result.compQty = val.parseInt
    of cmdEnd:
      echo "done parsing"

