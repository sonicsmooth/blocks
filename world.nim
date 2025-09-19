import std/math

# Type conversion to world coordinate types.
# This is not pan/zoom.  See viewport for pan/zoom.
# This is more about converting numbers and tuples to
# world coordinate types and rounding if needed instead
# of truncating.

type
  WCoordT* = int # This may eventually be float or some very large integer
  WPoint* = tuple[x, y: WCoordT]

# Single dimension converting any type of number to a world coordinate
converter toWorldCoord*[T:SomeNumber](a: T): WCoordT =
  when T is SomeInteger and WCoordT is SomeInteger:
    a.WCoordT
  elif T is SomeFloat and WCoordT is SomeInteger:
    a.round.WCoordT
  elif WCoordT is SomeFloat:
    a.WCoordT
  else:
    echo "Weird condition"
    echo getStackTrace()

# Two dimensions converting any type of tuple with x, y to a world point
converter toWorldPoint*(pt: tuple[x, y: SomeNumber]): WPoint =
  (pt[0].toWorldCoord, pt[1].toWorldCoord) 
  
# Two dimensions converting any type of tuple with width, height to a world size
converter toWorldSize*(pt: tuple[width, height: SomeNumber]): WPoint =
  (pt[0].toWorldCoord, pt[1].toWorldCoord) 
  


when isMainModule:
  import wNim/wTypes
  echo "3 -> ", toWorldCoord(3)
  echo "4.5 -> ", toWorldCoord(4.5)
  echo "(10, 20) -> ", toWorldPoint((10, 20))
  echo "(0, 0) -> ", (0,0).toWorldPoint
  echo "(3.0, 5.5) -> ", toWorldPoint((3.0, 5.5))
  var x: WPoint
  x = (10.2, 11.5).WPoint
  echo "(10.2, 11.5) -> ", x