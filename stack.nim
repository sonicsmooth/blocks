import std/[algorithm, sugar, sequtils]
from rects import DBComp
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
proc vertCmp (r1, r2: DBComp): int = cmp(r1.bbox.h, r2.bbox.h)
proc horizCmp(r1, r2: DBComp): int = cmp(r1.bbox.w, r2.bbox.w)

proc stackCompactSub(table: var RectTable, rects: seq[CompID], dstRect: var WRect, direction: CompactDir) =
  # Compact given IDs into given rect
  var accRects: seq[CompID]
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
      if bbox.bottom < dstRect.bottom:
        dstRect.x = bbox.right
        accRects = @[rect.id]
    of LeftDown:
      if bbox.top > dstRect.top:
        dstRect.x = bbox.right
        accRects = @[rect.id]
    of RightUp:
      if bbox.bottom < dstRect.bottom:
        dstRect.x -= bbox.w
        accRects = @[rect.id]
    of RightDown:
      if bbox.top > dstRect.top:
        dstRect.x -= bbox.w
        accRects = @[rect.id]
    of UpLeft:
      if bbox.right > dstRect.right:
        dstRect.y -= bbox.h
        accRects = @[rect.id]
    of UpRight:
      if bbox.left < dstRect.left:
        dstRect.y -= bbox.h
        accRects = @[rect.id]
    of DownLeft:
      if bbox.right > dstRect.right:
        dstRect.y = bbox.top
        accRects = @[rect.id]
    of DownRight:
      if bbox.left < dstRect.left:
        dstRect.y = bbox.top
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

    when WType is SomeInteger:
      let maxval = WType.high
      let minval = WType.low
    elif WType is SomeFloat:
      # Todo: how to get this without inf?
      let maxval = 1e10
      let minval = -1e10
    let rgd = rect.bbox.greatestDim
    rect.x = if isXAscending(direction): maxval - rgd  # stack from left to right
             else:                       minval + rgd  # stack from right to left
    rect.y = if isYAscending(direction): maxval - rgd  # stack from bottom to top
             else:                       minval + rgd  # stack from top to bottom
  stackCompactSub(table, rects.ids, dstRect, direction)






