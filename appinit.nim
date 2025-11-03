import std/[json]
export json


# Read inits json file
# Various parts of the app read from here
# for example grid visible is read by the toolbar,
# the panel checkbox, and the grid itself
# This is read only.  Any changes to shared state that 
# happen after initial loading up of these values
# has to be managed elsewhere
# TODO: Make this file a live read so if you change
# TODO: then stuff updates immediately
# TODO: Use Jsony

let
  appInits = parseFile("appinit.json")["appInits"]
  gAppOptsJ*: JsonNode = appInits["AppOpts"]
  gViewportJ*: JsonNode = appInits["Viewport"]
  gZctrlJ*: JsonNode = appInits["Zctrl"]
  gGridSpecsJ*: JsonNode = appInits["Grid"]
  gPanelSpecsJ*: JsonNode = appInits["MainPanel"]
