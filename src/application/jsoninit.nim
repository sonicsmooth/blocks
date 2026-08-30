import std/[os, json]
export json


# Read inits json file
# Various parts of the app read from here
# for example grid visible is read by the toolbar,
# the panel checkbox, and the grid itself
# TODO: Make this file a live read so if you change
# TODO: then stuff updates immediately
# TODO: Use Jsony

var
  gAppOptsJ*: JsonNode
  gViewportJ*: JsonNode
  gZctrlJ*: JsonNode
  gGridSpecsJ*: JsonNode
  gPanelSpecsJ*: JsonNode
  # gRenderSpecsJ*: JsonNode

# TODO: move rendering options to a new gRenderSpecsJ

proc jsonInitGlobals*() =
  try:
    # Assume we have to go down one dir from exe location
    # Assume exe location has been fixed in nim.cfg 
    let initPath = getAppDir() / "../appinit.json"
    if fileExists(initPath):
      echo "Opening ", initPath
      let initsJ   = parseFile(initPath)["appInits"]
      gAppOptsJ    = initsJ["AppOpts"]
      gViewportJ   = initsJ["Viewport"]
      gZctrlJ      = initsJ["Zctrl"]
      gGridSpecsJ  = initsJ["Grid"]
      gPanelSpecsJ = initsJ["MainPanel"]
    else:
      echo "Cannot open ", initPath
  except CatchableError as e:
    echo "Key not found in jsoninit.nim"
    echo e.msg

when isMainModule:
  jsonInitGlobals()
  echo gAppOptsJ.pretty()
