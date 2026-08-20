

type
  Rotation* = enum R0, R90, R180, R270

proc rotate*[T: SomeNumber](pt: tuple[x, y: T], amt: Rotation, pivot: tuple[x, y: T]): auto =
  # This is not a fancy rotator
  # Since it only deals with 90-degree increments, we
  # are only swapping and negating x,y values
  let offsetx = pt.x - pivot.x
  let offsety = pt.y - pivot.y
  var x,y: T

  case amt
  of R0:
    x = offsetx
    y = offsety
  of R90:
    x = -offsety
    y =  offsetx
  of R180:
    x = -offsetx
    y = -offsety
  of R270:
    x =  offsety
    y = -offsetx
  (x + pivot.x, y + pivot.y)

proc toFloat*(rot: Rotation): float =
  case rot:
  of R0: 0.0
  of R90: 90.0
  of R180: 180.0
  of R270: 270.0
proc inc*(r: var Rotation) =
  case r:
  of R0:   r = R90
  of R90:  r = R180
  of R180: r = R270
  of R270: r = R0
proc dec*(r: var Rotation) =
  case r:
  of R0:   r = R270
  of R90:  r = R0
  of R180: r = R90
  of R270: r = R180
proc `+`*(r1, r2: Rotation): Rotation =
  case r1:
  of R0: r2
  of R90:
    case r2:
    of R0: R90
    of R90: R180
    of R180: R270
    of R270: R0
  of R180:
    case r2:
    of R0: R180
    of R90: R270
    of R180: R0
    of R270: R90
  of R270:
    case r2:
    of R0: R270
    of R90: R0
    of R180: R90
    of R270: R180
proc `-`*(r1, r2: Rotation): Rotation =
  case r1:
  of R0:
    case r2:
    of R0: R0
    of R90: R270
    of R180: R180
    of R270: R90
  of R90:
    case r2:
    of R0: R90
    of R90: R0
    of R180: R270
    of R270: R180
  of R180:
    case r2:
    of R0: R180
    of R90: R90
    of R180: R0
    of R270: R270
  of R270:
    case r2:
    of R0: R270
    of R90: R180
    of R180: R90
    of R270: R0

when isMainModule:
  proc testRots() =
    var rot: Rotation
    assert R0.toFloat == 0.0
    assert R90.toFloat == 90.0
    assert R180.toFloat == 180.0
    assert R270.toFloat == 270.0
    rot.inc; assert rot == R90
    rot.inc; assert rot == R180
    rot.inc; assert rot == R270
    rot.inc; assert rot == R0
    rot.dec; assert rot == R270
    rot.dec; assert rot == R180
    rot.dec; assert rot == R90
    rot.dec; assert rot == R0
    assert R0   + R0   == R0
    assert R0   + R90  == R90
    assert R0   + R180 == R180
    assert R0   + R270 == R270
    assert R90  + R0   == R90
    assert R90  + R90  == R180
    assert R90  + R180 == R270
    assert R90  + R270 == R0
    assert R180 + R0   == R180
    assert R180 + R90  == R270
    assert R180 + R180 == R0
    assert R180 + R270 == R90
    assert R270 + R0   == R270
    assert R270 + R90  == R0
    assert R270 + R180 == R90
    assert R270 + R270 == R180
    assert R90  + R0   == R90
    assert R180 + R0   == R180
    assert R270 + R0   == R270
    assert R0   + R90  == R90
    assert R90  + R90  == R180
    assert R180 + R90  == R270
    assert R270 + R90  == R0
    assert R0   + R180 == R180
    assert R90  + R180 == R270
    assert R180 + R180 == R0
    assert R270 + R180 == R90
    assert R0   + R270 == R270
    assert R90  + R270 == R0
    assert R180 + R270 == R90
    assert R270 + R270 == R180
    assert R0   - R0   == R0
    assert R0   - R90  == R270
    assert R0   - R180 == R180
    assert R0   - R270 == R90
    assert R90  - R0   == R90
    assert R90  - R90  == R0
    assert R90  - R180 == R270
    assert R90  - R270 == R180
    assert R180 - R0   == R180
    assert R180 - R90  == R90
    assert R180 - R180 == R0
    assert R180 - R270 == R270
    assert R270 - R0   == R270
    assert R270 - R90  == R180
    assert R270 - R180 == R90
    assert R270 - R270 == R0
    assert R90  - R0   == R90
    assert R180 - R0   == R180
    assert R270 - R0   == R270
    assert R0   - R90  == R270
    assert R90  - R90  == R0
    assert R180 - R90  == R90
    assert R270 - R90  == R180
    assert R0   - R180 == R180
    assert R90  - R180 == R270
    assert R180 - R180 == R0
    assert R270 - R180 == R90
    assert R0   - R270 == R90
    assert R90  - R270 == R180
    assert R180 - R270 == R270
    assert R270 - R270 == R0

  testRots()
