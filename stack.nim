import std/[algorithm, sugar, sequtils]
from rects import DBRect
import recttable, compact


#[
Compact from largest to smallest into dstRect
For upper left stacking:
Sort by size and move to bottom right
For rect in rects:
  add rect to accumulator
  stack accumulator rects up then left into dstRect
  if right overflow then
    move dstRect down to bottom of bbox
    clear accumulator except for current rect
]#




# Comparison procs
proc vertCmp (r1, r2: DBRect): int = cmp(r1.size.h, r2.size.h)
proc horizCmp(r1, r2: DBRect): int = cmp(r1.size.w, r2.size.w)

proc stackCompactSub(table: var RectTable, rects: seq[RectID], dstRect: var WRect, direction: CompactDir) =
  # Compact given IDs into given rect
  var accRects: seq[RectID]
  for rect in table[rects]:
    accRects.add(rect.id)
    compact(table, direction.primax, direction.primAsc, dstRect, accRects)
    compact(table, direction.secax,  direction.secAsc,  dstRect, accRects)
    let bbox = boundingBox(table[accRects])

    # Left  arrow = stack from left to right, which is x ascending
    # Right arrow = stack from right to left, which is x descending
    # Up    arrow = stack from top to bottom, which is y descending
    # Down  arrow = stack from bottom to top, which is y ascending

    case compoundDir(direction):
    of LeftUp:
      if bbox.BottomEdge.y < dstRect.BottomEdge.y:
        dstRect.x = bbox.RightEdge.x
        accRects = @[rect.id]
    of LeftDown:
      if bbox.TopEdge.y > dstRect.TopEdge.y:
        dstRect.x = bbox.RightEdge.x
        accRects = @[rect.id]
    of RightUp:
      if bbox.BottomEdge.y < dstRect.BottomEdge.y:
        dstRect.x -= bbox.w
        accRects = @[rect.id]
    of RightDown:
      if bbox.TopEdge.y > dstRect.TopEdge.y:
        dstRect.x -= bbox.w
        accRects = @[rect.id]
    of UpLeft:
      if bbox.RightEdge.x > dstRect.RightEdge.x:
        dstRect.y -= bbox.h
        accRects = @[rect.id]
    of UpRight:
      if bbox.LeftEdge.x < dstRect.LeftEdge.x:
        dstRect.y -= bbox.h
        accRects = @[rect.id]
    of DownLeft:
      if bbox.RightEdge.x > dstRect.RightEdge.x:
        dstRect.y = bbox.TopEdge.y
        accRects = @[rect.id]
    of DownRight:
      if bbox.LeftEdge.x < dstRect.LeftEdge.x:
        dstRect.y = bbox.TopEdge.y
        accRects = @[rect.id]


proc stackCompact*(table: var RectTable, dstRect: WRect, direction: CompactDir) =
  # Rotate, sort by vertical or horizontal size, and move to opposite corner
  # Then launch stacking routine.
  var dstRect = dstRect
  var rects = table.values.toSeq
  
  if direction.primax == X:
    for rect in rects:
      rect.rotate(Horizontal)
    rects.sort(horizCmp, Descending)
  else:
    for rect in rects:
      rect.rotate(Vertical)
    rects.sort(vertCmp, Descending)

  for rect in rects:
    # Move everything to extreme position
    # For horiz, ascending is stack left to right (min to max)
    # therefore move everything right so there is some space
    # to move left into.  Back off a bit by the maximum amount a block might be
    rect.x = if isXAscending(direction): WCoordT.high - rect.greatestDim  # stack from left to right
             else:                       WCoordT.low  + rect.greatestDim  # stack from right to left
    rect.y = if isYAscending(direction): WCoordT.high - rect.greatestDim  # stack from bottom to top
             else:                       WCoordT.low  + rect.greatestDim  # stack from top to bottom
  stackCompactSub(table, rects.ids, dstRect, direction)






