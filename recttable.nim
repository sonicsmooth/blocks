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
  HoverTable* = ref Table[CompID, bool] # Probably meant to be shared
  SelectedTable* = ref Table[CompID, bool] # Probably meant to be shared
  SomeComps* = RectTable | seq[(CompID, DBComp)]

proc newRectTable*(): RectTable =
  newTable[CompID, DBComp]()

proc newHoverTable*(): HoverTable =
  newTable[CompID, bool]()

proc newSelectTable*(): SelectedTable =
  newTable[CompID, bool]()

# proc newPosTable*(): ref PosTable = 
#   newTable[CompID, PosRot]()

proc `$`*(table: RectTable): string =
  for k,v in table:
    result.add(&"{k}: {v}\n")

proc `[]`*(table: RectTable, idxs: openArray[CompID]): seq[rects.DBComp] =
  for idx in idxs:
    result.add(table[idx])

proc add*(table: RectTable, rect: rects.DBComp) =
  table[rect.id] = rect

proc selected*(table: SelectedTable): seq[CompID] =
  for id, sel in table:
    if sel:
      result.add(id)

proc notSelected*(table: SelectedTable): seq[CompID] =
  for id, sel in table:
    if not sel:
      result.add(id)

proc hovering*(table: HoverTable): seq[CompID] =
  for id, hov in table:
    if hov:
      result.add(id)

proc notHovering*(table: HoverTable): seq[CompID] =
  for id, hov in table:
    if not hov:
      result.add(id)

proc positions*(table: RectTable): PosTable =
  for id, rect in table:
    result[id] = (rect.x, rect.y, rect.rot)

proc setPositions*[T:Table](table: var RectTable, pos: T) =
  # Set rects in rectTable to positions
  for id, rect in table:
    rect.x = pos[id].x
    rect.y = pos[id].y

proc ptInRects*(table: SomeComps, pt: WPoint): seq[CompID] = 
  # Returns seq of DBComp IDs from table if pt in comp's bbox
  # surrounds or contacts pt
  # Optimization? -- return after first one
  for id, comp in table:
    if isPointInRect(pt, comp.bbox):
      result.add(id)

proc ptInRects*(table: SomeComps, pt: PxPoint, vp: Viewport): seq[CompID] = 
  # Returns seq of DBComp IDs from table if pt in comp's bbox
  # Pre-select by checking without converting every rect
  let wpt = pt.toWorld(vp)
  var preBbs: seq[(CompID, WRect)]
  for id, comp in table:
    let bb = comp.bbox
    if isPointInRect(wpt, bb):
      preBbs.add((id, bb))

  for (id, bb) in preBbs:
    let prect = bb.toPRect(vp)
    if isPointInRect(pt, prect):
      result.add(id)

proc rectInRects*(table: SomeComps, rect: WRect): seq[CompID] = 
  # Return seq of DBComp IDs from table that intersect rect
  # Return seq also includes rect
  # Typically rect is moving around and touches objs in table
  # Or rect is a bounding box and we're looking for where 
  # it touches other blocks
  for id, dbcomp in table:
    if isRectInRect(rect, dbcomp.bbox) or 
       isRectOverRect(rect, dbcomp.bbox):
      result.add(id)

proc rectInRects*(table: SomeComps, rect: PRect, vp: Viewport): seq[CompID] =
  # Return seq of DBComp IDs that intersect rect
  for id, dbcomp in table:
    let tpr = dbcomp.bbox.toPRect(vp)
    if isRectInRect(rect, tpr) or
       isRectOverRect(rect, tpr):
      result.add(id)

proc rectInRects*(table: RectTable, compId: CompID): seq[CompID] = 
  # Uses table[compId] and delegates to rectInRects above
  table.rectInRects(table[compId].bbox)



proc randomizeRectsAll*(table: var RectTable, region: WRect, qty: int, log: bool=false) = 
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


proc toggleRectSelect*(table: SelectedTable, id: CompID) = 
  table[id] = not table[id]
proc toggleRectSelect*(table: SelectedTable, ids: seq[CompID]) =
  for id in ids:
    table[id] = not table[id]
proc toggleRectSelect*(table: SelectedTable) =
  for v in table.mvalues:
    v = not v

proc clearRectSelect*(table: SelectedTable): seq[CompID] = 
  # Clear all selected ids, return previous selection
  result = table.selected
  for id in result:
    table[id] = false
proc clearRectSelect*(table: SelectedTable, id: CompID): bool =
  # Clear a specific id; return the old value
  result = table[id]
  table[id] = false
proc clearRectSelect*(table: SelectedTable, ids: seq[CompID]): seq[CompID] =
  # Clear the given ids; return the flipped ones
  let sel = ids.toSeq
  for id in sel:
    if table[id]:
      result.add(id)
    table[id] = false

proc setRectSelect*(table: SelectedTable): seq[CompID] {.discardable.} = 
  # Set all unselected ids; preturn previous unselection
  result = table.notSelected
  for id in result:
    table[id] = true
proc setRectSelect*(table: SelectedTable, id: CompID): bool =
  # Set specific id; return old value
  result = table[id]
  table[id] = true
proc setRectSelect*(table: SelectedTable, ids: seq[CompID]): seq[CompID] =
  # Set the given ids; return the flipped ones
  let sel = ids.toSeq
  for id in sel:
    if not table[id]:
      result.add(id)
    table[id] = true


proc toggleRectHovering*(table: HoverTable, id: CompID) = 
  table[id] = not table[id]
proc toggleRectHovering*(table: HoverTable, ids: seq[CompID]) =
  for id in ids:
    table[id] = not table[id]
proc toggleRectHovering*(table: HoverTable) =
  for v in table.mvalues:
    v = not v

proc clearRectHovering*(table: HoverTable): seq[CompID] = 
  result = table.hovering
  for id in result:
    table[id] = false
proc clearRectHovering*(table: HoverTable, id: CompID): bool =
  result = table[id]
  table[id] = false
proc clearRectHovering*(table: HoverTable, ids: seq[CompID]): seq[CompID] =
  let sel = ids.toSeq
  for id in sel:
    if table[id]:
      result.add(id)
    table[id] = false

proc setRectHovering*(table: HoverTable): seq[CompID] = 
  result = table.notSelected
  for id in result:
    table[id] = true
proc setRectHovering*(table: HoverTable, id: CompID): bool =
  result = table[id]
  table[id] = true
proc setRectHovering*(table: HoverTable, ids: seq[CompID]): seq[CompID] =
  let sel = ids.toSeq
  for id in sel:
    if not table[id]:
      result.add(id)
    table[id] = true

