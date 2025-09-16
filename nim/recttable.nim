import std/[random, sets, strformat, tables]
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
  RectTable* = ref Table[RectID, DBRect]   # meant to be shared
  PosRot = tuple[x: WCoordT, y: WCoordT, rot: Rotation]
  PosTable* = Table[RectID, PosRot] # meant to have value semantics

const
  QTY* = 20


proc newRectTable*(): RectTable =
  newTable[RectID, rects.DBRect]()

proc newPosTable*(): ref PosTable = 
  newTable[RectID, PosRot]()

proc `$`*(table: RectTable): string =
  for k,v in table:
    result.add(&"{k}: {v}\n")

proc `[]`*(table: RectTable, idxs: openArray[RectID]): seq[rects.DBRect] =
  for idx in idxs:
    result.add(table[idx])

proc add*(table: RectTable, rect: rects.DBRect) =
  table[rect.id] = rect


proc selected*(table: RectTable): seq[RectId] =
  for id, rect in table:
    if rect.selected:
      result.add(id)

proc notSelected*(table: RectTable): seq[RectId] =
  for id, rect in table:
    if not rect.selected:
      result.add(id)

proc positions*(table: RectTable): PosTable =
  for id, rect in table:
    result[id] = (rect.x, rect.y, rect.rot)

proc setPositions*[T:Table](table: var RectTable, pos: T) =
  # Set rects in rectTable to positions
  for id, rect in table:
    rect.x = pos[id].x
    rect.y = pos[id].y

proc ptInRects*(table: RectTable, pt: WPoint): seq[RectID] = 
  # Returns seq of DBRect IDs from table whose rect 
  # surrounds or contacts pt
  # Optimization? -- return after first one
  for id, rect in table:
    if isPointInRect(pt, rect):
      result.add(id)

proc rectInRects*(table: RectTable, rect: WRect|DBRect): seq[RectID] = 
  # Return seq of DBRect IDs from table that intersect rect
  # Return seq also includes rect
  # Typically rect is moving around and touches objs in table
  # Or rect is a bounding box and we're looking for where 
  # it touches other blocks
  for id, tabRect in table:
    if isRectInRect(rect, tabRect) or 
       isRectOverRect(rect, tabRect):
      result.add(id)

proc rectInRects*(table: RectTable, rectId: RectID): seq[RectID] = 
  table.rectInRects(table[rectId])

proc randomizeRectsAll*(table: var RectTable, panelSize: wSize, qty: int, log: bool=false) = 
  table.clear()
  when defined(testRects):
    echo "testRects"
    table[1] = DBRect(id: 1, x: 0, y: 0, w: 100, h: 100, origin: (0, 0), rot: R0,
                    selected: false, penColor: Blue, brushColor: Blue.colordiv(2).toColorU32(127))
    #table[1] = DBRect(id: 1, x: 0, y: 0, w: 100, h: 100, origin: (0, 0), rot: R0,
    #                selected: false, penColor: 0x7f0000ff.toColorU32, brushColor: 0x7f00007f.toColorU32)
    # table[2] = DBRect(id: 2, x: 100, y: 100, w: 100, h: 100, origin: (0,0), rot: R0,
    #                 selected: false, penColor: 0xffff0000.toColorU32, brushColor: 0x7fff0000.toColorU32)
  else:
    for i in 1..qty:
      let rid = i.RectID
      table[rid] = randRect(rid, panelSize, log)

proc randomizeRectsPos*(table: RectTable, panelSize: Size) =
  for id, rect in table:
    rect.x = rand(panelSize.w - rect.w  - 1)
    rect.y = rand(panelSize.h - rect.h - 1)

proc boundingBox*(rectTable: RectTable): WRect =
  rectTable.values.toSeq.boundingBox()

proc aspectRatio*(rtable: RectTable): float =
  rtable.values.toSeq.aspectRatio()

proc fillArea*(rtable: RectTable): WCoordT = 
  # Just the rectangle area
  rtable.values.toSeq.fillArea()

proc fillRatio*(rtable: RectTable): float =
  rtable.values.toSeq.fillRatio()


# Forward decls
proc toggleRectSelect*(table: RectTable, id: RectID)
proc toggleRectSelect*(table: RectTable, ids: seq[RectId]) {.discardable.}
proc toggleRectSelect*(table: RectTable) {.discardable.}
proc clearRectSelect*(table: RectTable): seq[RectId] {.discardable.}
proc clearRectSelect*(table: RectTable, id: RectID): bool {.discardable.}
proc clearRectSelect*(table: RectTable, ids: seq[RectId]): seq[RectId] {.discardable.}
proc setRectSelect*(table: RectTable): seq[RectId] {.discardable.}
proc setRectSelect*(table: RectTable, id: RectID): bool {.discardable.}
proc setRectSelect*(table: RectTable, ids: seq[RectId]): seq[RectId] {.discardable.}

proc toggleRectSelect*(table: RectTable, id: RectID) = 
  table[id].selected = not table[id].selected

proc toggleRectSelect*(table: RectTable, ids: seq[RectId]) =
  for rect in table.values:
    rect.selected = not rect.selected

proc toggleRectSelect*(table: RectTable) =
  for rect in table.values:
    rect.selected = not rect.selected


proc clearRectSelect*(table: RectTable): seq[RectId] = 
  result = table.selected
  for id in result:
    table[id].selected = false

proc clearRectSelect*(table: RectTable, id: RectID): bool =
  result = table[id].selected
  table[id].selected = false

proc clearRectSelect*(table: RectTable, ids: seq[RectId]): seq[RectId] =
  let sel = ids.toSeq
  for id in sel:
    if table[id].selected:
      result.add(id)
    table[id].selected = false


proc setRectSelect*(table: RectTable): seq[RectId] = 
  result = table.notSelected
  for id in result:
    table[id].selected = true

proc setRectSelect*(table: RectTable, id: RectID): bool =
  result = table[id].selected
  table[id].selected = true

proc setRectSelect*(table: RectTable, ids: seq[RectId]): seq[RectId] =
  let sel = ids.toSeq
  for id in sel:
    if not table[id].selected:
      result.add(id)
    table[id].selected = true

