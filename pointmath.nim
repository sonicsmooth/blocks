

# Hopefully this can cover all the +-*/ for different combinations of stuff

proc `+`*[T:SomeNumber](a: tuple[x, y: T], b: tuple[x, y: T]): auto =
  (a.x + b.x, a.y + b.y)

proc `+=`*[T:SomeNumber](a: var tuple[x, y: T], b: tuple[x, y: T]) =
  a = (a.x + b.x, a.y + b.y)

proc `-`*[T:SomeNumber](a: tuple[x, y: T], b: tuple[x, y: T]): auto =
  (a.x - b.x, a.y - b.y)

proc `-=`*[T:SomeNumber](a: var tuple[x, y: T], b: tuple[x, y: T]) =
  a = (a.x - b.x, a.y - b.y)

proc `*`*[TN:SomeNumber, TF: SomeFloat](a: tuple[x, y: TN], b: TF): auto =
  when SomeNumber is SomeInteger:
    ((a.x.TF * b).round.TN, 
     (a.y.TF * b).round.TN)
  else:
    (a.x.TF * b, a.y.TF * b)

# TODO figure out how to multiply PxSize, WSize, PxPoint, WPoint, etc.

when isMainModule:
  import rects
  assert (2,3) + (5,9) == (7, 12)
  assert (2'u16, 3'u16) + (5'u16,9'u16) == (7'u16, 12'u16)
  assert (2'u32, 3'u32) + (5'u32,9'u32) == (7'u32, 12'u32)
  assert (2'u64, 3'u64) + (5'u64,9'u64) == (7'u64, 12'u64)
  assert (-2'i64, 3'i64) + (5'i64, 9'i64) == (3'i64, 12'i64)
  assert (2.0, 3.0) + (5.0, 9.0) == (7.0, 12.0)

  var jt = (15,16)
  jt += (1,1)
  assert jt == (16, 17)
  jt -= (1,1)
  assert jt == (15, 16)

  var r = DBRect(x: 15, y: 20, w: 50, h: 30)
  assert r.pos + (10, 20) == (25, 40)
  echo (r.pos + (10, 20).WPoint).typeof
