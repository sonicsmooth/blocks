import std/math

iterator arange*[A:SomeNumber](slice: HSlice[A,A], step: A ): A =
  # Return range from slice with step A.
  # step sign will be ignored in liew of slice direction
  let up = slice.b >= slice.a
  let stp = if up: abs(step) else: -abs(step)
  var x = slice.a
  when A is SomeInteger:
    assert step > 0
    if slice.b >= slice.a:
      while x <= slice.b:
        yield x
        x += stp
    else:
      while x >= slice.b:
        yield x
        x += stp
  else:
    let numStps = (abs(slice.a - slice.b) / abs(step)).ceil().uint
    if slice.b >= slice.a:
      for i in 0 .. numStps:
        x = i.float * stp + slice.a
        if x < slice.b or almostEqual(x, slice.b, 10):
          yield x
    else:
      for i in 0 .. numStps:
        x = i.float * stp + slice.a
        if x > slice.b or almostEqual(x, slice.b, 10):
          yield x



when isMainModule:
  echo arange(1..5, 1).toSeq
  echo arange(1..5, 2).toSeq
  echo arange(1..5, 3).toSeq
  echo arange(5..1, 1).toSeq
  echo arange(5..1, 2).toSeq
  echo arange(5..1, 3).toSeq
  echo arange(0.0 .. 0.19,  0.09).toSeq
  echo arange(0.0 .. 0.20,  0.09).toSeq
  echo arange(0.0 .. 0.21,  0.09).toSeq
  echo arange(0.0 .. 0.29,  0.09).toSeq
  echo arange(0.0 .. 0.30,  0.09).toSeq
  echo arange(0.0 .. 0.31,  0.09).toSeq
  echo arange(1.0 .. 0.1,  -0.01).toSeq
  echo arange(1.0 .. 0.1,  0.01).toSeq
  echo arange(100.0 .. 0.0,  5.0).toSeq
