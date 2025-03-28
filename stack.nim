import std/[algorithm, sequtils]
import wnim/wtypes
import recttable, compact


# Compact from largest to smallest into the given rectangle
# case (primax, secax, primrev, secrev):
# of (x,y,false,false): stack to left,   then to top,    overflow down
# of (x,y,false,true):  stack to left,   then to bottom, overflow up
# of (x,y,true,false):  stack to right,  then to top,    overflow down
# of (x,y,true,true):   stack to right,  then to bottom, overflow up
# of (y,x,false,false): stack to top,    then to left,   overflow right
# of (y,x,false,true):  stack to top,    then to right,  overflow left
# of (y,x,true,false):  stack to bottom, then to left,   overflow right
# of (y,x,true,true):   stack to bottom, then to right,  overflow left

proc vertCmp (r1, r2: Rect): int = cmp(r1.size.height, r2.size.height)
proc horizCmp(r1, r2: Rect): int = cmp(r1.size.width,  r2.size.width )

proc stackCompact*(table: var RectTable, dstRect: wRect, direction: CompactDir) =

  var dstRect = dstRect
  # Rotate, sort by vertical size, and move to opposite corner
  var rects = table.values.toSeq
  var accRects: seq[RectID]
  
  for rect in rects:
    rect.rotate(Vertical)

  rects.sort(vertCmp, Descending) 

  for rect in rects:
    # TODO: use HRANGE.high
    rect.x = int32.high - 1000 # TODO figure out why this is needed, why -1000, why not int?
    rect.y = int32.high - 1000 # TODO figure out why this is needed, why -1000, why not int?

  for rect in rects:
    accRects.add(rect.id)
    compact(table, direction.secax,  direction.secrev,  dstRect, accRects)
    compact(table, direction.primax, direction.primrev, dstRect, accRects)
    if rect.rightEdge.x > dstRect.rightEdge.x:
      let bbox = boundingBox(table[accRects])
      let newY = bbox.bottomEdge.y
      dstRect.y = newY
      accRects.setLen(0)
      accRects.add(rect.id)





