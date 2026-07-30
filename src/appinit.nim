import std/[json]
export json


# Read inits json file
# Various parts of the app read from here
# for example grid visible is read by the toolbar,
# the panel checkbox, and the grid itself
# TODO: Make this file a live read so if you change
# TODO: then stuff updates immediately
# TODO: Use Jsony

var
  appInitsJ: JsonNode
  gAppOptsJ*: JsonNode
  gViewportJ*: JsonNode
  gZctrlJ*: JsonNode
  gGridSpecsJ*: JsonNode
  gPanelSpecsJ*: JsonNode

proc appInit*() =
  appInitsJ = parseFile("../appinit.json")["appInits"]
  gAppOptsJ = appInitsJ["AppOpts"]
  gViewportJ = appInitsJ["Viewport"]
  gZctrlJ = appInitsJ["Zctrl"]
  gGridSpecsJ = appInitsJ["Grid"]
  gPanelSpecsJ = appInitsJ["MainPanel"]
