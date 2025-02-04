

type InnerIter[T] = iterator(to2:T): tuple[v:T,m:string] {.closure.}

iterator counter(frm, to: float, msg: string): tuple[v:float,m:string] {.closure.} =
  var x = frm
  while x < to:
    yield (x, msg)
    x += 1.0

iterator myIt1[T]():T {.closure.} =
  var x:T = 0.T
  while x<10: 
    yield x
    inc x

# template makeCounter:untyped =
#   iterator myIt2[T]():T {.closure.} =
#     var x:T = 0.T
#     while x<10: 
#       yield x
#       inc x
  

# var ctr = makeCounter
# echo ctr()
# echo ctr()
# echo ctr()

import std/[tables, sequtils]
import wnim
type RectID = int
type PosTable = ref Table[RectID, wPoint]

proc t1(tab: PosTable): int =
  tab.keys.toSeq.len

proc t2[T:PosTable](tab:T): int = 
  tab.keys.toSeq.len

proc t3[T:ref Table](tab:T): int =
  tab.keys.toSeq.len



var tab = PosTable()
#new tab
tab[1] = (0,0)
tab[4] = (2,3)
tab[10] = (15,20)
echo t1(tab)
echo t2(tab)
echo t3(tab)

# # var rtab:ref PosTable 
# # new rtab
# # rtab[] = {1:(0,0), 4:(2,3), 10:(15,20)}.toTable
# let rtab:PosTableRef = {1:(0,0), 4:(2,3), 10:(15,20)}.toTable

# echo t1(rtab)
# echo t2(rtab)
# echo t3(rtab)

