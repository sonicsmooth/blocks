import std/[random, sets, strformat, tables]
from std/sequtils import toSeq
import wNim/[wTypes]
import rects
export rects

type 
  RectTable* = ref Table[RectID, Rect]   # meant to be shared
  PosTable* = Table[RectID, wPoint] # meant to have value semantics


proc newRectTable*(): RectTable =
  newTable[RectID, Rect]()

proc newPosTable*(): ref PosTable = 
  newTable[RectID, wPoint]()

proc `$`*(table: RectTable): string =
  for k,v in table:
    result.add(&"{k}: {v}\n")

proc `[]`*(table: RectTable, idxs: openArray[RectID]): seq[Rect] =
  for idx in idxs:
    result.add(table[idx])

proc selected*(table: RectTable): seq[RectId] =
  for id, rect in table:
    if rect.selected:
      result.add(id)

proc positions*(table: RectTable): PosTable =
  for id, rect in table:
    result[id] = (rect.x, rect.y)

proc setPositions*[T:Table](table: var RectTable, pos: T) =
  # Set rects in rectTable to positions
  for id, rect in table:
    rect.x = pos[id].x
    rect.y = pos[id].y

proc ptInRects*(table: RectTable, pt: wPoint): seq[RectID] = 
  # Returns seq of Rect IDs from table whose rect 
  # surrounds or contacts pt
  # Optimization? -- return after first one
  for id, rect in table:
    if isPointInRect(pt, rect.wRect):
      result.add(id)

proc rectInRects*(table: RectTable, rect: wRect): seq[RectID] = 
  # Return seq of Rect IDs from table that intersect rect
  # Return seq also includes rect
  # Typically rect is moving around and touches objs in table
  # Or rect is a bounding box and we're looking for where 
  # it touches other blocks
  for id, tabRect in table:
    if isRectInRect(rect, tabRect.wRect) or 
       isRectOverRect(rect, tabRect.wRect):
      result.add(id)

proc rectInRects*(table: RectTable, rectId: RectID): seq[RectID] = 
  table.rectInRects(table[rectId].wRect)

proc randomizeRectsAll*(table: var RectTable, size: wSize, qty: int) = 
  table.clear()
  for i in 1..qty:
    let rid = toRectId(i)
    table[rid] = randRect(rid, size)

proc randomizeRectsAllLog*(table: var RectTable, size: wSize, qty: int) = 
  # Randomize in a way that has fewer large blocks and more small blocks
  table.clear()
  for i in 1..qty:
    let rid = toRectId(i)
    table[rid] = randRect(rid, size)

proc randomizeRectsPos*(table: RectTable, screenSize: wSize) =
  for id, rect in table:
    rect.x = rand(screenSize.width  - rect.width  - 1)
    rect.y = rand(screenSize.height - rect.height - 1)

proc boundingBox*(rectTable: RectTable): wRect =
  boundingBox(rectTable.values.toSeq)

proc aspectRatio*(rtable: RectTable): float =
  rtable.values.toSeq.aspectRatio

proc fillRatio*(rtable: RectTable): float =
  rtable.values.toSeq.fillRatio


# Forward decls
proc toggleRectSelect*(table: RectTable, id: RectID) 
proc toggleRectSelect*(table: RectTable, ids: seq[RectId] | HashSet[RectId])
proc toggleRectSelect*(table: RectTable)
proc clearRectSelect*(table: RectTable)
proc clearRectSelect*(table: RectTable, id: RectID, only: bool=false)
proc clearRectSelect*(table: RectTable, ids: seq[RectId] | HashSet[RectId], only: bool=false)
proc setRectSelect*(table: RectTable)
proc setRectSelect*(table: RectTable, id: RectID, only: bool=false)
proc setRectSelect*(table: RectTable, ids: seq[RectId] | HashSet[RectId], only: bool=false)

proc toggleRectSelect*(table: RectTable, id: RectID) = 
  echo "togglingA ", id
  table[id].selected = not table[id].selected

proc toggleRectSelect*(table: RectTable, ids: seq[RectId] | HashSet[RectId]) =
  # Todo: check if this copies openArray, or add when... case
  #let sel = ids.toSeq
  #echo "tolling allB"
  for rect in table.values:
    echo "togglingB ", rect.id
    rect.selected = not rect.selected

proc toggleRectSelect*(table: RectTable) =
  #echo "tolling allC"
  for rect in table.values:
    echo "togglingC ", rect.id
    rect.selected = not rect.selected


proc clearRectSelect*(table: RectTable) = 
  # Clear all
  #echo "clearing allD"
  for rect in table.values:
    if rect.selected:
      echo "clearingD ", rect.id
      # TODO: check if it's faster to do if-then-else
      # TODO: vs just setting everything to false
      rect.selected = false

proc clearRectSelect*(table: RectTable, id: RectID, only: bool=false) =
  if only: # Set all before setting id
    setRectSelect(table)
  echo "clearingE ", id
  table[id].selected = false

proc clearRectSelect*(table: RectTable, ids: seq[RectId] | HashSet[RectId], only: bool=false) =
  # Todo: check if this copies openArray, or add when... case
  if only: # Set all before setting ids
    setRectSelect(table)
  let sel = ids.toSeq
  for id in sel:
    echo "clearingF ", id
    table[id].selected = false


proc setRectSelect*(table: RectTable) = 
  # select all
  #echo "setting allG"
  for id, rect in table:
    echo "  settingG ", id
    rect.selected = true

proc setRectSelect*(table: RectTable, id: RectID, only: bool=false) =
  if only: # Clear all before setting id
    clearRectSelect(table)
  echo "settingH ", id
  table[id].selected = true

proc setRectSelect*(table: RectTable, ids: seq[RectId] | HashSet[RectId], only: bool=false) =
  # Todo: check if this copies openArray, or add when... case
  if only: # Clear all before setting ids
    clearRectSelect(table)
  let sel = ids.toSeq
  for id in sel:
    echo "settingI ", id
    table[id].selected = true

