import std/[algorithm,
            #sugar,
            sequtils, 
            tables]


import compact
import document
from rects import DBComp


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


proc compoundDir*(spec: CompactSpec): CornerDir =
  # Left  arrow = stack from left to right, which is x ascending
  # Right arrow = stack from right to left, which is x descending
  # Up    arrow = stack from top to bottom, which is y descending
  # Down  arrow = stack from bottom to top, which is y ascending
  assert(spec.secondary.isSome)
  let p = spec.primary
  let s = spec.secondary
  let compound = (p.axis == X, p.sortOrder, s.get().sortOrder)
  if   compound == (false, Ascending,  Ascending ): DownLeft
  elif compound == (false, Ascending,  Descending): DownRight
  elif compound == (false, Descending, Ascending ): UpLeft
  elif compound == (false, Descending, Descending): UpRight
  elif compound == (true,  Ascending,  Ascending ): LeftDown
  elif compound == (true,  Ascending,  Descending): LeftUp
  elif compound == (true,  Descending, Ascending ): RightDown
  else: RightUp


# Comparison procs
proc vertCmp (r1, r2: DBComp): int = cmp(r1.wbbox.h, r2.wbbox.h)
proc horizCmp(r1, r2: DBComp): int = cmp(r1.wbbox.w, r2.wbbox.w)

proc stackCompactSub(table: var RectTable, rects: seq[CompID], dstRect: var WRect, spec: CompactSpec) =
  # Compact in 2 directions
  # Compact given IDs into given rect

  # Verify this is actually a compound direction, i.e. has both primary and secondary axes
  assert(spec.secondary.isSome)

  var accRects: seq[CompID]
  for rect in table[rects]:
    accRects.add(rect.id)
    compact(table, spec.primary.axis, spec.primary.sortOrder, dstRect, accRects)
    compact(table, spec.secondary.get().axis, spec.secondary.get().sortOrder, dstRect, accRects)
    let bbox = boundingBox(table.dbComps(accRects))

    # Left  arrow = stack from left to right, which is x ascending
    # Right arrow = stack from right to left, which is x descending
    # Up    arrow = stack from top to bottom, which is y descending
    # Down  arrow = stack from bottom to top, which is y ascending

    case compoundDir(spec):
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

proc isXAscending*(spec: CompactSpec): bool =
  (spec.primary.axis == X and spec.primary.sortOrder == Ascending) or
  (spec.secondary.get().axis == X and spec.secondary.get().sortOrder == Ascending)

proc isYAscending*(spec: CompactSpec): bool = 
  (spec.primary.axis == Y and spec.primary.sortOrder == Ascending) or
  (spec.secondary.get().axis == Y and spec.secondary.get().sortOrder == Ascending)

proc stackCompact*(table: var RectTable, dstRect: WRect, spec: CompactSpec) =
  # Rotate, sort by vertical or horizontal size, and move to opposite corner
  # Then launch stacking routine.
  var dstRect = dstRect
  var rects = table.values.toSeq
  
  if spec.primary.axis == X:
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
    let rgd = rect.wbbox.greatestDim
    rect.x = if isXAscending(spec): maxval - rgd  # stack from left to right
             else:                  minval + rgd  # stack from right to left
    rect.y = if isYAscending(spec): maxval - rgd  # stack from bottom to top
             else:                  minval + rgd  # stack from top to bottom
  stackCompactSub(table, rects.ids, dstRect, spec)






