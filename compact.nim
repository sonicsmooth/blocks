
import rects

type Axis* = enum X, Y

proc compact*(rectTable: RectTable, axis: Axis, reverse: bool) = 
  echo rectTable
  echo axis
  echo reverse
