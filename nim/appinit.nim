import std/[json]
export json

# Read inits json file
# Various parts of the app read from here
# for example grid visible is read by the toolbar,
# the panel checkbox, and the grid itself
# This is read only.  Any changes to shared state that 
# happen after initial loading up of these values
# has to be managed elsewhere

let
  appInits = parseFile("appinit.json")["appInits"]
  gGridSpecs*: JsonNode = appInits["gridSpecs"]
  gPanelSpecs*: JsonNode = appInits["panelSpecs"]
