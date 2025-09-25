import std/math

# Type conversion to world coordinate types.
# This is not pan/zoom.  See viewport for pan/zoom.
# This is more about converting numbers and tuples to
# world coordinate types and rounding if needed instead
# of truncating.

type
  WType* = int # This may eventually be float or some very large integer
  WPoint* = tuple[x, y: WType]
  WSize* = tuple[w, h: WType]
  PxType* = cint
  PxPoint* = tuple[x, y: PxType] # same as sdl2.Point
  PxSize* = tuple[w, h: PxType]
  SomePoint* = WPoint | PxPoint
  SomeSize* = WSize | PxSize

# Single dimension converting any type of number to a world coordinate
converter toWType*[T:SomeNumber](a: T): WType =
  when T is SomeInteger and WType is SomeInteger:
    a.WType
  elif a is SomeFloat and WType is SomeInteger:
    a.round.WType
  elif WType is SomeFloat:
    a.WType
  else:
    raise newException(TypeError, "Weird Condition")

converter toPxType*[T:SomeNumber](a: T): PxType =
  # PxType is always an integer
  when T is SomeInteger:
    a.PxType
  elif T is SomeFloat:
    a.round.PxType


converter toWPoint*[T:SomeNumber](pt: tuple[x, y: T]): WPoint  =
  (pt[0],  pt[1]) # toWType is called implicitly for each part of tuple

converter toWSize*[T:SomeNumber](pt: tuple[w, h: T]): WSize   =
  (pt[0],  pt[1]) # toWType is called implicitly for each part of tuple

converter toPxPoint*[T:SomeNumber](pt: tuple[x, y: T]): PxPoint =
  (pt[0], pt[1]) # toPxType is called implicitly for each part of tuple

converter toPxSize*[T:SomeNumber](pt: tuple[w, h: T]): PxSize  =
  (pt[0], pt[1]) # toPxType is called implicitly for each part of tuple



when isMainModule:
  when WType is int:
    assert toWType(3) == 3
    assert toWType(4.1) == 4
    assert toWType(4.5) == 5
    let p1 = (10, 20)
    assert p1.WPoint == (x:10, y:20)
    assert toWPoint((x:10, y:20))     == (10, 20)
    assert toWPoint((10.1, 20.1)) == (10, 20)
    assert toWPoint((10.5, 20.5)) == (x:11, y:21)
    assert toWSize((10, 20))      == (10, 20)
    assert toWSize((10.1, 20.1))  == (10, 20)
    assert toWSize((10.5, 20.5))  == (w:11, h:21)
    echo "int assertions done"
  
  elif WType is float:
    assert toWType(3) == 3.0
    assert toWType(4.1) == 4.1
    assert toWType(4.5) == 4.5
    let p1 = (10, 20)
    assert p1.WPoint == (x:10, y:20)
    assert toWPoint((x:10, y:20)) == (10.0, 20.0)
    assert toWPoint((10.1, 20.1)) == (10.1, 20.1)
    assert toWPoint((10.5, 20.5)) == (x:10.5, y:20.5)
    assert toWSize((10, 20))      == (10.0, 20.0)
    assert toWSize((10.1, 20.1))  == (10.1, 20.1)
    assert toWSize((10.5, 20.5))  == (w:10.5, h:20.5)
    echo "float assertions done"
