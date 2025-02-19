# Simulated annealing
import std/[algorithm, locks, math, os, random, sets, sugar, strformat]
from sequtils import toSeq
#from std/os import sleep
import wnim, winim/inc/winuser
from wnim/private/wHelper import `+`
import concurrent, rects

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

const NUM_NEXT_STATES = 500
const MAX_TEMP* = 100.0
const TEMP_STEP = 1
const MINPROB = 0.1    # low end of probability distribution function
const MAXPROB = 10.0  # high end of probability distribution function
type 
  NextStateFunc* = enum Wiggle, Swap
var 
  RND = initRand()


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

proc calcSwap*[T](table: var T, temp: float) =
  # Swap some pairs of blocks' positions.  Temperature 
  # determines how many blocks are moved.
  # Mutates table in place
  let maxSwap = 1.0  # Proportion of blocks that will move at MAX_TEMP
  let tempPct = temp / MAX_TEMP
  let numRects = 2 * (floor(table.len.float * maxSwap * tempPct / 2.0)).int
  let ids = table.keys.toSeq
  let rpairs = select(ids, numRects).pairs
  #let pairTable: Table[typeof(ids[0]), typeof(ids[0])] = rpairs.toTable
  let pairTable = rpairs.toTable # to -> id mapping
  # Go through each table entry matching selected IDs
  var idSet = ids.toHashSet # {all ids}
  while idSet.len > 0:
    let a = idSet.pop
    if a in pairTable:
      let aPos = (table[a].x, table[a].y)
      let b = pairTable[a]
      let bPos = (table[b].x, table[b].y)
      result[a].x = bPos.x
      result[a].y = bPos.y
      result[b].x = aPos.x
      result[b].y = aPos.y
      idSet.excl(b)
    #else:
    #  result[a] = A

proc calcWiggle*[S,pT](initState: S, pTable: pT, temp: float, maxAmt: wSize) =
  # Copies x,y values from initState to pTable with some amount
  # changed based on temperature
  # initState must have at least the same keys as varTable.
  # Both tables must have x,y properties
  # Mutates varTable in place
  for id, item in pTable[]:
    let amt = moveAmt(temp, maxAmt)
    item.x = initState[id].x + amt.x
    item.y = initState[id].y + amt.y

proc capturePos[T](capTable: var Table[float, PosTable], 
                   varTable: T, 
                   heur: float) =
  if capTable.len < 25:
    capTable[heur] = varTable
  else:
    # Table is full, so make some choices
    let heurs = capTable.keys.toSeq
    let hmin = heurs.min
    let hmax = heurs.max
    if heur > hmin and heur < hmax:
      capTable.del(hmin)
      capTable[heur] = varTable

proc makeCdf(length: uint): seq[float] =
  let expScale = ln(MAXPROB / MINPROB) / (length.float - 1.0)
  let pdf = collect(
    for x in 0..<length: 
      MINPROB * exp(x.float * expScale))
  pdf.cumsummed

# Totally premature optimization
proc makeCdf25(): seq[float] {.compileTime.} =
  let expScale = ln(MAXPROB / MINPROB) / 24.0
  let pdf = collect(
    for x in 0..<25: 
      MINPROB * exp(x.float * expScale))
  pdf.cumsummed


#proc selectBestCapture(capTable: Table[float, PosTable]): auto = 
proc selectHeuristic(heuristics: openArray[float]): float = 
  # Chooses random heuristic with bias towards better ones
  # The highest scoring heuristic is maybe 5-10x more likely to be 
  # chosen than the lowest, with an exponential curve in between
  if heuristics.len == 1:
    heuristics[0]
  else:
    let heurs = heuristics.sorted
    let cdf = 
      if heurs.len == 25: 
        makeCdf25()
      else:
        makeCdf(heurs.len.uint)
    sample(RND, heurs, cdf)



proc annealWiggle*(arg: AnnealArg) {.thread.} =
  # Copy initState back to table after each NUM_NEXT_STATES itefillRation
  acquire(gLock)
  let startTemp = MAX_TEMP
  let endTemp = 0.0
  let moveScale = 0.25
  let maxAmt: wSize = ((arg.screenSize.width.float  * moveScale).int,
                       (arg.screenSize.height.float * moveScale).int)
  
  var interState = arg.initState
  var best25: Table[float, PosTable]
  var bestEver: tuple[heur: float, table: PosTable]
  var temp = startTemp
  var firstTime = true
  var heur:float
  while temp > endTemp:
    if firstTime:
      firstTime = false
    else: # second time, etc.
      let chosenHeur = selectHeuristic(best25.keys.toSeq) # Choose random with heuristic bias
      interState = best25[chosenHeur]
      best25.clear()

    for i in 1..NUM_NEXT_STATES:
      calcWiggle(interState, arg.pRectTable, temp, maxAmt)
      {.gcsafe.}: arg.compactfn()
      heur = arg.pRectTable[].fillRatio
      #heur = varTable.fillRatio / abs(1-varTable.aspectRatio)
      let poses = arg.pRectTable[].positions
      if heur > bestEver.heur:
        echo &"{temp}: {heur}"
        bestEver = (heur, poses)
      capturePos(best25, poses, heur)
    echo "showing"
    {.gcsafe.}: arg.showfn()
    sleep(1)
    temp -= TEMP_STEP
  # Set positions
  for id,pos in bestEver.table:
    arg.pRectTable[][id].x = pos.x
    arg.pRectTable[][id].y = pos.y
  release(gLock)

proc doNothing*() {.thread.} =
  for i in 1..10:
    echo "DoNothing"
    sleep(1000)
  echo "thread done"

proc randomWorker*(arg: RandomArg) {.thread.} =
  let size = (600,400)
  let qty  = 100
  for i in 1..100:
    withLock(gLock):
      randomizeRectsAll(arg.pRectTable[], size, qty)
    SendMessage(arg.window.mHwnd, WM_APP+5, 0, 0)
    discard gAckChan.recv()
    