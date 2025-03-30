import std/[algorithm, sequtils]
import wnim/wtypes
import recttable, compact


# Compact from largest to smallest into the given rectangle

proc vertCmp (r1, r2: Rect): int = cmp(r1.size.height, r2.size.height)
proc horizCmp(r1, r2: Rect): int = cmp(r1.size.width,  r2.size.width )
proc stackCompact*(table: var RectTable, dstRect: wRect, direction: CompactDir) =
  var dstRect = dstRect
  # Rotate, sort by vertical size, and move to opposite corner
  var rects = table.values.toSeq
  var accRects: seq[RectID]
  
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

  for rect in rects:
    accRects.add(rect.id)
    compact(table, direction.primax, direction.primrev, dstRect, accRects)
    compact(table, direction.secax,  direction.secrev,  dstRect, accRects)
    let bbox = boundingBox(table[accRects])

    case compoundDir(direction):
    of UpLeft:
      if bbox.rightEdge.x > dstRect.rightEdge.x:
        dstRect.y = bbox.bottomEdge.y
        accRects = @[rect.id]
    of UpRight:
      if bbox.leftEdge.x < dstRect.leftEdge.x:
        dstRect.y = bbox.bottomEdge.y
        accRects = @[rect.id]
    of DownLeft:
      if bbox.rightEdge.x > dstRect.rightEdge.x:
        dstRect.y -= bbox.height
        accRects = @[rect.id]
    of DownRight:
      if bbox.leftEdge.x < dstRect.leftEdge.x:
        dstRect.y -= bbox.height
        accRects = @[rect.id]
    of LeftUp:
      if bbox.bottomEdge.y > dstRect.bottomEdge.y:
        dstRect.x = bbox.rightEdge.x
        accRects = @[rect.id]
    of LeftDown:
      if bbox.topEdge.y < dstRect.topEdge.y:
        dstRect.x = bbox.rightEdge.x
        accRects = @[rect.id]
    of RightUp:
      if bbox.bottomEdge.y > dstRect.bottomEdge.y:
        dstRect.x -= bbox.width
        accRects = @[rect.id]
    of RightDown:
      if bbox.topEdge.y < dstRect.topEdge.y:
        dstRect.x -= bbox.width
        accRects = @[rect.id]






