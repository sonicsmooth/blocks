import std/json
export json


# Read inits json file
# Various parts of the app read from here
# for example grid visible is read by the toolbar,
# the panel checkbox, and the grid itself
# TODO: Make this file a live read so if you change
# TODO: then stuff updates immediately
# TODO: Use Jsony

var
  initsJ: JsonNode
  gAppOptsJ*: JsonNode
  gViewportJ*: JsonNode
  gZctrlJ*: JsonNode
  gGridSpecsJ*: JsonNode
  gPanelSpecsJ*: JsonNode

proc jsonInit*() =
  initsJ = parseFile("../appinit.json")["appInits"]
  gAppOptsJ = initsJ["AppOpts"]
  gViewportJ = initsJ["Viewport"]
  gZctrlJ = initsJ["Zctrl"]
  gGridSpecsJ = initsJ["Grid"]
  gPanelSpecsJ = initsJ["MainPanel"]
