import std/[math, random]
from std/sugar import collect

const
  MINPROB = 0.1    # low end of probability distribution function
  MAXPROB = 10.0  # high end of probability distribution function

var 
  RND* = initRand()

proc makeCdf*(length: int, mnp: float=MINPROB, mxp: float=MAXPROB): seq[float] =
  # return cumulative distribution function from mnp to mxp of length length
  let expScale = ln(mxp / mnp) / (length.float - 1.0)
  let pdf = collect(
    for x in 0..<length: 
      mnp * exp(x.float * expScale))
  pdf.cumsummed

# Totally premature optimization
proc makeCdf25*(): seq[float] {.compileTime.} =
  # return cumulative distribution function of length 25 at compile time
  let expScale = ln(MAXPROB / MINPROB) / 24.0
  let pdf = collect(
    for x in 0 ..< 25: 
      MINPROB * exp(x.float * expScale))
  pdf.cumsummed

proc select*[T](a: openArray[T], qty: int): seq[T] =
  # Choose qty unique samples from a using global RND state
  while result.len < qty:
    let s = RND.sample(a)
    if s in result:
      continue
    result.add(s)

    
