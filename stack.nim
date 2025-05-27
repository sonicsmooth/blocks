import std/[algorithm, sugar, sequtils]
from sdl2 import Rect
import recttable, compact


# Compact from largest to smallest into the given rectangle

proc vertCmp (r1, r2: rects.Rect): int = cmp(r1.size.h, r2.size.h)
proc horizCmp(r1, r2: rects.Rect): int = cmp(r1.size.w, r2.size.w)

proc stackCompactSub(table: var RectTable, rects: seq[RectID], dstRect: var PRect, direction: CompactDir) =
  # Compact given IDs into given rect
  var accRects: seq[RectID]
  for rect in table[rects]:
    accRects.add(rect.id)
    compact(table, direction.primax, direction.primAsc, dstRect, accRects)
    compact(table, direction.secax,  direction.secAsc,  dstRect, accRects)
    let bbox = boundingBox(table[accRects])

    case compoundDir(direction):
    of UpLeft:
      if bbox.RightEdge.x > dstRect.RightEdge.x:
        dstRect.y = bbox.BottomEdge.y
        accRects = @[rect.id]
    of UpRight:
      if bbox.LeftEdge.x < dstRect.LeftEdge.x:
        dstRect.y = bbox.BottomEdge.y
        accRects = @[rect.id]
    of DownLeft:
      if bbox.RightEdge.x > dstRect.RightEdge.x:
        dstRect.y -= bbox.h
        accRects = @[rect.id]
    of DownRight:
      if bbox.LeftEdge.x < dstRect.LeftEdge.x:
        dstRect.y -= bbox.h
        accRects = @[rect.id]
    of LeftUp:
      if bbox.BottomEdge.y > dstRect.BottomEdge.y:
        dstRect.x = bbox.RightEdge.x
        accRects = @[rect.id]
    of LeftDown:
      if bbox.TopEdge.y < dstRect.TopEdge.y:
        dstRect.x = bbox.RightEdge.x
        accRects = @[rect.id]
    of RightUp:
      if bbox.BottomEdge.y > dstRect.BottomEdge.y:
        dstRect.x -= bbox.w
        accRects = @[rect.id]
    of RightDown:
      if bbox.TopEdge.y < dstRect.TopEdge.y:
        dstRect.x -= bbox.w
        accRects = @[rect.id]


proc stackCompact*(table: var RectTable, dstRect: PRect, direction: CompactDir) =
  var dstRect = dstRect
  # Rotate, sort by vertical size, and move to opposite corner
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
    rect.x = if isXAscending(direction): int32.high - WRANGE.b
             else:                       int32.low
    rect.y = if isYAscending(direction): int32.high - HRANGE.b
             else:                       int32.low

  stackCompactSub(table, rects.ids, dstRect, direction)






