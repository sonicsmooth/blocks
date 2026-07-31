import std/[random, sets, strformat, tables]
from std/sequtils import toSeq
import wNim/[wTypes]
import rects, colors, appopts
export rects, tables


# TODO: Migrate move, rotate, etc., to this module
# TODO: instead of doing them individually where needed
# TODO: Accomodate do-all, or do-selected

# TODO: Unify functions for individual rects into tables
# TODO: example rotate, move, id, position, assign field value, etc.

type 
  RectTable* = ref Table[CompID, DBComp]   # meant to be shared
  PosRot = tuple[x: WType, y: WType, rot: Rotation]
  PosTable* = Table[CompID, PosRot] # meant to have value semantics
  CompSet = ref HashSet[CompID] #Table[CompID, bool]
  HoverSet* = CompSet # Probably meant to be shared
  SelectedSet* = CompSet # Probably meant to be shared
  SomeComps* = RectTable | seq[(CompID, DBComp)]

proc newRectTable*(): RectTable =
  newTable[CompID, DBComp]()

proc newHoverSet*(): HoverSet =
  new result # init is automatic

proc newSelectedSet*(): SelectedSet =
  new result # init is automatic

proc `$`*(table: RectTable): string =
  for k,v in table:
    result.add(&"{k}: {v}\n")

proc `[]`*(table: RectTable, idxs: openArray[CompID]): seq[rects.DBComp] =
  for idx in idxs:
    result.add(table[idx])

proc add*(table: RectTable, rect: rects.DBComp) =
  table[rect.id] = rect

proc positions*(table: RectTable): PosTable =
  for id, rect in table:
    result[id] = (rect.x, rect.y, rect.rot)

proc setPositions*[T:Table](table: var RectTable, pos: T) =
  # Set rects in rectTable to positions
  for id, rect in table:
    rect.x = pos[id].x
    rect.y = pos[id].y

proc ptInComps*(table: SomeComps, pt: WPoint): seq[CompID] = 
  # Returns seq of DBComp IDs from table if pt in comp's bbox
  # surrounds or contacts pt
  # Optimization? -- return after first one
  for id, comp in table:
    if isPointInRect(pt, comp.bbox):
      result.add(id)

proc ptInComps*(table: SomeComps, pt: PxPoint, vp: Viewport): seq[CompID] = 
  # Returns seq of DBComp IDs from table if pt in comp's bbox
  # Pre-select by checking without converting every rect
  #! check logic here.  Not sure this is necessary
  let wpt = pt.toWorld(vp)
  var preBbs: seq[(CompID, WRect)]

  # Add the model space bounding box if point is in it
  for id, comp in table:
    let bb = comp.bbox
    if isPointInRect(wpt, bb):
      preBbs.add((id, bb))

  # Add the id if the point is in the bounding box in pixel space
  # Seems like what we just did... not sure why this is the way it is
  for (id, bb) in preBbs:
    let prect = bb.toPRect(vp)
    if isPointInRect(pt, prect):
      result.add(id)

proc rectInComps*(table: SomeComps, rect: WRect): seq[CompID] = 
  # Return seq of DBComp IDs from table that intersect rect
  # Return seq also includes rect
  # Typically rect is moving around and touches objs in table
  # Or rect is a bounding box and we're looking for where 
  # it touches other blocks
  for id, comp in table:
    if isRectInRect(rect, comp.bbox) or 
       isRectOverRect(rect, comp.bbox):
      result.add(id)

proc rectInComps*(table: SomeComps, rect: PRect, vp: Viewport): seq[CompID] =
  # Return seq of DBComp IDs that intersect rect
  for id, comp in table:
    let tpr = comp.bbox.toPRect(vp)
    if isRectInRect(rect, tpr) or
       isRectOverRect(rect, tpr):
      result.add(id)

proc rectInComps*(table: RectTable, compId: CompID): seq[CompID] = 
  # Uses table[compId] and delegates to rectInComps above
  # I think this checks whether compId intersects with anything
  # else in the table
  table.rectInComps(table[compId].bbox)



proc randomizeRectsAll*(table: var RectTable, qty: int, region: WRect, log: bool=false) = 
  table.clear()
  if qty == 1:
    table[ 1] = DBComp(id:  1, x: 0, y:  0, w: 52, h: 102, origin: (0, 0), rot: R0, 
                penColor: Red, fillColor: colorByName[gAppOpts.singleColor])
  else:
    for i in 1..qty:
      let rid = i.CompID
      table[rid] = randRect(rid, region, log)

proc randomizeRectsPos*(table: RectTable, region: WRect) =
  for id, rect in table:
    rect.x = region.x + rand(region.w)
    rect.y = region.y + rand(region.h)

proc boundingBox*(table: RectTable): WRect =
  table.values.toSeq.boundingBox

# proc aspectRatio*(table: RectTable): float =
#   table.values.toSeq.boundingBox.aspectRatio()

proc fillArea*(rtable: RectTable): WType = 
  # Just the rectangle area
  rtable.values.toSeq.bboxes.fillArea()

proc fillRatio*(rtable: RectTable): float =
  rtable.values.toSeq.bboxes.fillRatio()

proc trueItems*(comps: CompSet): seq[CompID] =
  comps[].toSeq

proc falseItems*(comps: CompSet, table: RectTable): seq[CompID] =
  for id in table.keys:
    if id notin comps[]:
      result.add(id)

proc toggleOne*(comps: CompSet, id: CompID) = 
  if id in comps[]:
    comps[].excl(id)
  else:
    comps[].incl(id)
proc toggleSome*(comps: CompSet, ids: seq[CompID]) {.discardable.} =
  for id in ids:
    toggleOne(comps, id)
proc toggleAll*(comps: CompSet, table: RectTable) =
  for id in table.keys:
    toggleOne(comps, id)

proc clearOne*(comps: CompSet, id: CompID): bool =
  # Clear a specific id; return the old value
  result = id in comps[]
  comps[].excl(id)
proc clearSome*(comps: CompSet, ids: seq[CompID]): seq[CompID] {.discardable.}=
  # Clear the given ids; return the flipped ones
  for id in ids:
    if id in comps[]:
      result.add(id)
    comps[].excl(id)
proc clearAll*(comps: CompSet): seq[CompID] {.discardable.} = 
  # Clear all selected ids, return previous selection
  result = comps.trueItems
  comps[].clear()

proc setOne*(comps: CompSet, id: CompID): bool {.discardable.} =
  # Set specific id; return old value
  result = id in comps[]
  comps[].incl(id)
proc setSome*(comps: CompSet, ids: seq[CompID]): seq[CompID] {.discardable.} =
  # Set the given ids; return the flipped ones
  for id in ids:
    if id notin comps[]:
      result.add(id)
    comps[].incl(id)
proc setAll*(comps: CompSet, table: RectTable): seq[CompID] {.discardable.} = 
  # Set all unselected ids; preturn previous unselection
  result = comps.falseItems(table)
  for id in table.keys:
    comps[].incl(id)
