# Simulated annealing
import std/[random, math, sets]
from sequtils import toSeq
import wnim
from wnim/private/wHelper import `+`
import rects

# At each temperature generate 100 randomized next states
# The higher the temperature, the more each block moves around
# After gathering 100 next states, randomly choose the next
# starting state for the next temperature.  The random choice
# is actually weighted by the fitness of each next state.

#[ 
  Strategy 1 -- Randomize from startingState
  nextStates can either move blocks around or swap pairs
  availableStates = @[startingState]: SortedList[<25]
  store first fitness value
  for t in MAX_TEMP..0:
    seedState = biased random choice from availableStates
    for state in nextStates(seedState):
      compact and measure fitness
      if fitness in top 25, add non-compacted state to available states
      
  Stratgey 2 -- Randomize from compact state
  availableStates = @[startingState.compact]: SortedList[<25]
  store first fitness value
  for t in MAX_TEMP..0:
    seedState = biased random choice from availableStates
    for state in nextStates(seedState):
      compact and measure fitness
      option -- compact can use min distance based on temp
      if fitness in top 25, add compacted state to available states

    ]#

const NUM_NEXT_STATES = 50
const MAX_TEMP* = 100.0
var RND = initRand()
type NextStateFunc* = enum Wiggle, Swap


proc select[T](a: openArray[T], n: int): seq[T] =
  # Choose n samples from a
  while result.len < n:
    let s = RND.sample(a)
    if s in result:
      continue
    result.add(s)

proc pairs[T](a: openArray[T]): seq[(T, T)] =
  # Return contents of a as tuple-pairs
  let uselen = if (a.len mod 2) != 0: a.len - 1 else: a.len
  var i: int
  while i < uselen:
    result.add((a[i], a[i+1]))
    i += 2

proc moveAmt(temp: float, maxAmt: wSize): wPoint =
  # At maximum temp, maximum move is wSize/2
  let maxX = maxAmt.width.float  * temp / MAX_TEMP
  let maxY = maxAmt.height.float * temp / MAX_TEMP
  let xmv  = (rand(maxX) - maxX/2.0).int
  let xmy  = (rand(maxY) - maxY/2.0).int
  result = (xmv, xmy)

proc calcNextStateWiggle[T](startingState: T, temp: float, maxAmt: wSize): T {.inline.} =
  # Move each block by some random amount depending on temperature
  for id, poswidth in startingState:
    let amt = moveAmt(temp, maxAmt)
    result[id] = (poswidth.x + amt.x, 
                  poswidth.y + amt.y, 
                  poswidth.width, poswidth.height)

iterator nextStatesWiggle*(startingState: PositionTable, screenSize: wSize, temp: float,): PositionTable =
  # Yield next states from existing state
  let moveScale = 0.25
  let maxAmt: wSize = ((screenSize.width.float  * moveScale).int,
                       (screenSize.height.float * moveScale).int)
  for i in 1..NUM_NEXT_STATES:
    yield calcNextStateWiggle(startingState, temp, maxAmt)

iterator strategy1*(startingState: PositionTable, screenSize: wSize): PositionTable {.closure.} =
  for temp in countdown(MAX_TEMP.int, 0, 5):
    for ns in nextStatesWiggle(startingState, screenSize, temp.float):
      yield ns


proc calcNextStateSwap(startingState: PositionTable, temp: float): PositionTable =
  # Swap some pairs of blocks.  How many depends on temperature.
  let maxSwap = 1.0  # Proportion of blocks that will move at MAX_TEMP
  let tempPct = temp / MAX_TEMP
  let numRects = 2 * (floor(startingState.len.float * maxSwap * tempPct / 2.0)).int
  let ids = startingState.keys.toSeq
  let rpairs = select(ids, numRects).pairs
  let pairTable: Table[typeof(ids[0]), typeof(ids[0])] = rpairs.toTable
  var idSet = ids.toHashSet
  while idSet.len > 0:
    let a = idSet.pop
    let A = startingState[a]
    if a in pairTable:
      let b = pairTable[a]
      let B = startingState[b]
      result[a] = B
      result[b] = A
      idSet.excl(b)
    else:
      result[a] = A

iterator nextStatesSwap*(startingState: PositionTable, temp: float): PositionTable =
  # Yield next states from existing state
  var heur = startingState.ratio
  for i in 1..NUM_NEXT_STATES:
    echo heur
    let nextState = calcNextStateSwap(startingState, temp)
    heur = nextState.ratio 
    yield nextState

iterator strategy2*(startingState: PositionTable, screenSize: wSize): PositionTable {.closure.} =
  for temp in countdown(MAX_TEMP.int, 0, 5):
    for ns in nextStatesSwap(startingState, temp.float):
      yield ns

