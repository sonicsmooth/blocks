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

proc stackCompact*(table: ptr RectTable, dstRect: wRect, direction: CompactDir) =
  echo "compact stack from: ", dstrect, " dir: ", direction
