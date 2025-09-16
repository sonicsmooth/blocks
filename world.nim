import std/math

# Type conversion to world coordinate types.
# This is not pan/zoom.  See viewport for pan/zoom.
# This is more about converting numbers and tuples to
# world coordinate types and rounding if needed instead
# of truncating.

type
  WCoordT* = int # This may eventually be float or some very large integer
  Point* = tuple[x, y: WCoordT]

# Single dimension converting any type of number to a world coordinate
converter toWorldCoord*[T:SomeNumber](a: T): WCoordT =
  when T is WCoordT:
    echo "here1: ", a
    a
  elif WCoordT is SomeInteger and T is SomeFloat:
    echo "here2: ", a
    a.round.WCoordT
  elif WCoordT is SomeFloat:
    echo "here3: ", a
    a.WCoordT

# Two dimensions converting any type of tuple with x, y to a world point
converter toWorldPoint*(pt: tuple[x, y: SomeNumber]): Point =
  (pt[0].toWorldCoord, pt[1].toWorldCoord) 
  # when T is WCoordT:
  #   result = pt
  # elif WCoordT is SomeInteger and T is SomeFloat:
  #   result = (pt[0].round.WCoordT, pt[1].round.WCoordT)
  # elif WCoordT is SomeFloat:
  #   result = (pt[0].WCoordT, pt[1].WCoordT)
  
# Two dimensions converting any type of tuple with width, height to a world size
converter toWorldSize*(pt: tuple[width, height: SomeNumber]): Point =
  (pt[0].toWorldCoord, pt[1].toWorldCoord) 
  # when T is WCoordT:
  #   result = pt
  # elif WCoordT is SomeInteger and T is SomeFloat:
  #   result = (pt[0].round.WCoordT, pt[1].round.WCoordT)
  # elif WCoordT is SomeFloat:
  #   result = (pt[0].WCoordT, pt[1].WCoordT)
  


when isMainModule:
  import wNim/wTypes
  echo "3 -> ", toWorldCoord(3)
  echo "4.5 -> ", toWorldCoord(4.5)
  echo "(10, 20) -> ", toWorldPoint((10, 20))
  echo "(0, 0) -> ", (0,0).toWorldPoint
  echo "(3.0, 5.5) -> ", toWorldPoint((3.0, 5.5))
  var x: Point
  x = (10.2, 11.5).Point
  echo "(10.2, 11.5) -> ", x