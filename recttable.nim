import std/[random, sets, strformat, sugar, tables]
import timeit
from std/sequtils import toSeq
import wNim/[wTypes]
import rects, colors
export rects, tables

# TODO: Find a way to partition blocks into different regions
# TODO: Each region has a list of the blocks that are in it
# TODO: Each region is maybe split into further regions.
# TODO: The idea is that you can find a block in O(log(n)) time
# TODO: rather than O(n) time, when searching by x,y coordinate
# TODO: This is maybe where a proper database comes into play.
# if leftedge in set_11_00
#    if leftedge in set_10_00
#      do stuff
#    else # in set_01_00
# else # in set_00_11
#    if leftedge in set_00_10:
#      do stuff
#    else # in set_00_01:
#      do stuff

# TODO: Migrate move, rotate, etc., to this module
# TODO: instead of doing them individually where needed
# TODO: Accomodate do-all, or do-selected

# TODO: Unify functions for individual rects into tables
# TODO: example rotate, move, id, position, assign field value, etc.

type 
  RectTable* = ref Table[CompID, DBComp]   # meant to be shared
  PosRot = tuple[x: WType, y: WType, rot: Rotation]
  PosTable* = Table[CompID, PosRot] # meant to have value semantics
  SomeComps* = RectTable | seq[(CompID, DBComp)]

const
  QTY* = 200
  
var
  componentsVisible*: seq[DBComp]

proc newRectTable*(): RectTable =
  newTable[CompID, rects.DBComp]()

proc newPosTable*(): ref PosTable = 
  newTable[CompID, PosRot]()

proc `$`*(table: RectTable): string =
  for k,v in table:
    result.add(&"{k}: {v}\n")

proc `[]`*(table: RectTable, idxs: openArray[CompID]): seq[rects.DBComp] =
  for idx in idxs:
    result.add(table[idx])

proc add*(table: RectTable, rect: rects.DBComp) =
  table[rect.id] = rect


proc selected*(table: RectTable): seq[CompID] =
  for id, rect in table:
    if rect.selected:
      result.add(id)

proc notSelected*(table: RectTable): seq[CompID] =
  for id, rect in table:
    if not rect.selected:
      result.add(id)

proc hovering*(table: RectTable): seq[CompID] =
  for id, rect in table:
    if rect.hovering:
      result.add(id)

proc notHovering*(table: RectTable): seq[CompID] =
  for id, rect in table:
    if not rect.hovering:
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

proc ptInRects*(table: SomeComps, pt: PxPoint, vp: ViewPort): seq[CompID] = 
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

proc rectInRects*(table: SomeComps, rect: PRect, vp: ViewPort): seq[CompID] =
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
  when defined(testRects):
    table[ 1] = DBComp(id:  1, x: 0, y:  0, w: 52, h: 102, origin: (0, 0), rot: R0, selected: false, penColor: Red, fillColor: Lavender)
    # table[ 2] = DBComp(id:  2, x: 1, y: 10, w: 5, h: 5, origin: (1, 0), rot: R0, selected: false, penColor: Red, fillColor: Blue)
    # table[ 3] = DBComp(id:  3, x: 2, y: 20, w: 5, h: 5, origin: (2, 0), rot: R0, selected: false, penColor: Red, fillColor: Blue)
    # table[ 4] = DBComp(id:  4, x: 3, y: 30, w: 5, h: 5, origin: (3, 0), rot: R0, selected: false, penColor: Red, fillColor: Blue)
    # table[ 5] = DBComp(id:  5, x: 4, y: 40, w: 5, h: 5, origin: (4, 0), rot: R0, selected: false, penColor: Red, fillColor: Blue)
    # table[ 6] = DBComp(id:  6, x: 10, y: 10, w: 5, h: 5, origin: (2, 2), rot: R90,  selected: false, penColor: Red, fillColor: Blue)
    # table[ 7] = DBComp(id:  7, x: 20, y: 10, w: 5, h: 5, origin: (2, 2), rot: R180, selected: false, penColor: Red, fillColor: Blue)
    # table[ 8] = DBComp(id:  8, x: 30, y: 10, w: 5, h: 5, origin: (2, 2), rot: R270, selected: false, penColor: Red, fillColor: Blue)
    # table[ 9] = DBComp(id:  9, x:  0, y: 20, w: 5, h: 5, origin: (4, 4), rot: R0,   selected: false, penColor: Red, fillColor: Blue)
    # table[10] = DBComp(id: 10, x: 10, y: 20, w: 5, h: 5, origin: (4, 4), rot: R90,  selected: false, penColor: Red, fillColor: Blue)
    # table[11] = DBComp(id: 11, x: 20, y: 20, w: 5, h: 5, origin: (4, 4), rot: R180, selected: false, penColor: Red, fillColor: Blue)
    # table[12] = DBComp(id: 12, x: 30, y: 20, w: 5, h: 5, origin: (4, 4), rot: R270, selected: false, penColor: Red, fillColor: Blue)

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


# Forward decls
proc toggleRectSelect*(table: RectTable, id: CompID)
proc toggleRectSelect*(table: RectTable, ids: seq[CompID]) {.discardable.}
proc toggleRectSelect*(table: RectTable) {.discardable.}
proc clearRectSelect*(table: RectTable): seq[CompID] {.discardable.}
proc clearRectSelect*(table: RectTable, id: CompID): bool {.discardable.}
proc clearRectSelect*(table: RectTable, ids: seq[CompID]): seq[CompID] {.discardable.}
proc setRectSelect*(table: RectTable): seq[CompID] {.discardable.}
proc setRectSelect*(table: RectTable, id: CompID): bool {.discardable.}
proc setRectSelect*(table: RectTable, ids: seq[CompID]): seq[CompID] {.discardable.}

proc toggleRectHovering*(table: RectTable, id: CompID)
proc toggleRectHovering*(table: RectTable, ids: seq[CompID]) {.discardable.}
proc toggleRectHovering*(table: RectTable) {.discardable.}
proc clearRectHovering*(table: RectTable): seq[CompID] {.discardable.}
proc clearRectHovering*(table: RectTable, id: CompID): bool {.discardable.}
proc clearRectHovering*(table: RectTable, ids: seq[CompID]): seq[CompID] {.discardable.}
proc setRectHovering*(table: RectTable): seq[CompID] {.discardable.}
proc setRectHovering*(table: RectTable, id: CompID): bool {.discardable.}
proc setRectHovering*(table: RectTable, ids: seq[CompID]): seq[CompID] {.discardable.}


proc toggleRectSelect*(table: RectTable, id: CompID) = 
  table[id].selected = not table[id].selected
proc toggleRectSelect*(table: RectTable, ids: seq[CompID]) =
  for rect in table.values:
    rect.selected = not rect.selected
proc toggleRectSelect*(table: RectTable) =
  for rect in table.values:
    rect.selected = not rect.selected

proc clearRectSelect*(table: RectTable): seq[CompID] = 
  result = table.selected
  for id in result:
    table[id].selected = false
proc clearRectSelect*(table: RectTable, id: CompID): bool =
  result = table[id].selected
  table[id].selected = false
proc clearRectSelect*(table: RectTable, ids: seq[CompID]): seq[CompID] =
  let sel = ids.toSeq
  for id in sel:
    if table[id].selected:
      result.add(id)
    table[id].selected = false

proc setRectSelect*(table: RectTable): seq[CompID] = 
  result = table.notSelected
  for id in result:
    table[id].selected = true
proc setRectSelect*(table: RectTable, id: CompID): bool =
  result = table[id].selected
  table[id].selected = true
proc setRectSelect*(table: RectTable, ids: seq[CompID]): seq[CompID] =
  let sel = ids.toSeq
  for id in sel:
    if not table[id].selected:
      result.add(id)
    table[id].selected = true


proc toggleRectHovering*(table: RectTable, id: CompID) = 
  table[id].hovering = not table[id].hovering
proc toggleRectHovering*(table: RectTable, ids: seq[CompID]) =
  for rect in table.values:
    rect.hovering = not rect.hovering
proc toggleRectHovering*(table: RectTable) =
  for rect in table.values:
    rect.hovering = not rect.hovering

proc clearRectHovering*(table: RectTable): seq[CompID] = 
  result = table.hovering
  for id in result:
    table[id].hovering = false
proc clearRectHovering*(table: RectTable, id: CompID): bool =
  result = table[id].hovering
  table[id].hovering = false
proc clearRectHovering*(table: RectTable, ids: seq[CompID]): seq[CompID] =
  let sel = ids.toSeq
  for id in sel:
    if table[id].hovering:
      result.add(id)
    table[id].hovering = false

proc setRectHovering*(table: RectTable): seq[CompID] = 
  result = table.notSelected
  for id in result:
    table[id].hovering = true
proc setRectHovering*(table: RectTable, id: CompID): bool =
  result = table[id].hovering
  table[id].hovering = true
proc setRectHovering*(table: RectTable, ids: seq[CompID]): seq[CompID] =
  let sel = ids.toSeq
  for id in sel:
    if not table[id].hovering:
      result.add(id)
    table[id].hovering = true

