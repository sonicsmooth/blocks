

# Hopefully this can cover all the +-*/ for different combinations of stuff

proc `+`*[T:SomeNumber](a: tuple[x, y: T], b: tuple[x, y: T]): tuple[x, y: T] =
  (a.x + b.x, a.y + b.y)

proc `+=`*[T:SomeNumber](a: var tuple[x, y: T], b: tuple[x, y: T]) =
  a = (a.x + b.x, a.y + b.y)

proc `-`*[T:SomeNumber](a: tuple[x, y: T], b: tuple[x, y: T]): tuple[x, y: T] =
  (a.x - b.x, a.y - b.y)

proc `-=`*[T:SomeNumber](a: var tuple[x, y: T], b: tuple[x, y: T]) =
  a = (a.x - b.x, a.y - b.y)

proc `*`*[TN:SomeNumber, TF: SomeFloat](a: tuple[x, y: TN], b: TF): tuple[x, y: TF] =
  (a.x.TF * b, a.y.TF * b)

# proc `*`*[TN:SomeNumber, TF: SomeFloat](a: tuple[w, h: TN], b: TF): tuple[w, h: TF] =
#   (a.w.TF * b, a.h.TF * b)

# TODO figure out how to multiply PxSize, WSize, PxPoint, WPoint, etc.

when isMainModule:
  echo (2,3) + (5,9)
  echo (2'u16, 3'u16) + (5'u16,9'u16)
  echo (2'u32, 3'u32) + (5'u32,9'u32)
  echo (2'u64, 3'u64) + (5'u64,9'u64)
  echo (-2'i64, 3'i64) + (5'i64,9'i64)
  echo (2.0, 3.0) + (5.0, 9.0)


  var jt = (15,16)
  echo jt
  echo jt+jt
  jt += (1,1)
  echo jt
  jt -= (1,1)
  echo jt