import std/[algorithm, sugar, sequtils]
from sdl2 import Rect
import recttable, compact


# Compact from largest to smallest into the given rectangle

proc vertCmp (r1, r2: rects.Rect): int = cmp(r1.size.h, r2.size.h)
proc horizCmp(r1, r2: rects.Rect): int = cmp(r1.size.w, r2.size.w)

proc stackCompact*(table: var RectTable, dstRect: PRect, direction: CompactDir) =
  var dstRect = dstRect
  # Rotate, sort by vertical size, and move to opposite corner
  var rects = table.values.toSeq
  var accRects: seq[RectID]
  
  echo "here 1"
  if direction.primax == X:
    echo "here 2"
    for rect in rects:
      rect.rotate(Horizontal)
    rects.sort(horizCmp, Descending)
  else:
    echo "here 3"
    for rect in rects:
      rect.rotate(Vertical)
    echo "here 4"
    rects.sort(vertCmp, Descending)

  echo "here 5"
  for rect in rects:
    echo "here 6"
    rect.x = if isXAscending(direction): int32.high - WRANGE.b
             else:                       int32.low
    rect.y = if isYAscending(direction): int32.high - HRANGE.b
             else:                       int32.low

  echo "here 7"
  for rect in rects:
    echo "here 8"
    accRects.add(rect.id)
    echo "here 9"
    dump table
    dump direction.primAsc
    dump direction.secAsc
    dump dstRect
    dump accRects
    compact(table, direction.primax, direction.primAsc, dstRect, accRects)
    echo "here 10"
    compact(table, direction.secax,  direction.secAsc,  dstRect, accRects)
    echo "here 11"
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





