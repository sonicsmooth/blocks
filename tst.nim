

type InnerIter[T] = iterator(to2:T): tuple[v:T,m:string] {.closure.}

iterator counter(frm, to: float, msg: string): tuple[v:float,m:string] {.closure.} =
  var x = frm
  while x < to:
    yield (x, msg)
    x += 1.0

template makeCounter =
  let frm = 5
  let to = 10
  iterator(to2: T): tuple[v:T,m:string] {.closure.} = 
    let frmfloat = frm.T
    for x in counter(frmfloat, to2, msg):
      yield x


var ctr = makeCounter

while not ctr.finished:
  echo ctr(20.0)