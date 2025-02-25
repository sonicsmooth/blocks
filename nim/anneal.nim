# Simulated annealing
import std/[algorithm, locks, math, os, random, sets, sugar, strformat, tables]
import sequtils
import wnim
import winim/inc/[windef,winuser]
import concurrent, userMessages
import blockRand, arange, rects

# At each temperature generate 100 randomized next states
# The higher the temperature, the more each block moves around
# After gathering 100 next states, choose the best (or nearly
# best) of these as the starting state for the next temperature.
# The "nearly best" is actually weighted by the heuristic.

#[ 
  Strategy 1 -- Randomize from startingState
  interState <- initial State
  For temp in MaxTemp .. 0:
    interState <- biased best of 25
    For 1.. NumNextStates:
      perturb rectTable with PerturbFn
      compact and calc heuristic
      capture rectTable positions if heur in top 25
      
  Strategy 2 -- Randomize from compact state
  Compact first and calc heuristic
  interState <- first compacted state
  For temp in MaxTemp .. 0:
    interState <- biased best of 25
    For 1.. NumNextStates:
      perturb rectTable with PerturbFn
      compact and calc heuristic
      *option -- compact can use min distance based on temp
      capture rectTable positions if heur in top 25

    ]#

type
  Strategy* = enum Strat1, Strat2
  PerturbFn[S,pT] = proc(initState: S, pTable: pT, temp: float) {.closure.}
  AnnealArg* = tuple
    pRectTable: ptr RectTable
    strategy:   Strategy
    perturbFn:  PerturbFn[PosTable, ptr RectTable]
    compactFn:  proc() {.closure.}
    window:     wWindow
    initBmp:    bool
  RandomArg* = tuple
    pRectTable: ptr RectTable
    window:  wWindow


const
  NumNextStates = 20
  MaxTemp = 100.0
  MinTemp = 0.0
  TempStep = 2.0
  MinProb = 0.1   # low end of probability distribution function
  MaxProb = 10.0  # high end of probability distribution function

var
  gAnnealThread*: Thread[AnnealArg]

proc pairs[T](a: openArray[T]): seq[(T, T)] =
  # Return contents of a as tuple-pairs
  let uselen = if (a.len mod 2) != 0: a.len - 1 else: a.len
  var i: int
  while i < uselen:
    result.add((a[i], a[i+1]))
    i += 2

proc moveAmt(temp: float, maxAmt: wSize): wPoint =
  # At maximum temp, maximum move is wSize/2
  let maxX = maxAmt.width.float  * temp / MaxTemp
  let maxY = maxAmt.height.float * temp / MaxTemp
  let xmv  = (rand(maxX) - maxX/2.0).int
  let xmy  = (rand(maxY) - maxY/2.0).int
  result = (xmv, xmy)

proc calcSwap*[S,pT](initState: S, pTable: pT, temp: float) =
  # Copies x,y values from initState to pTable with some blocks
  # swapped based on temperature
  # initState must have at least the same keys as varTable.
  # Both tables must have x,y properties
  # Mutates pTable in place
  let maxSwap = 1.0  # Proportion of blocks that will move at MaxTemp
  let tempPct = temp / MaxTemp
  let numRects = 2 * (floor(pTable[].len.float * maxSwap * tempPct / 2.0)).int
  let ids = initState.keys.toSeq
  var idSet = ids.toHashSet # {all ids}
  let rpairs = select(ids, numRects).pairs

  # Just copy everything over if there are no swap pairs
  if rpairs.len == 0:
    for id, pos in initState:
      ptable[][id].x = pos.x
      ptable[][id].y = pos.y
    return

  # Go through each table entry matching selected IDs
  let pairTable = rpairs.toTable # to -> id mapping
  while idSet.len > 0:
    let a = idSet.pop
    if a in pairTable:
      let b = pairTable[a]
      let aPos: wPoint = (initState[a].x, initState[a].y)
      let bPos: wPoint = (initState[b].x, initState[b].y)
      pTable[][a].x = bPos.x
      pTable[][a].y = bPos.y
      pTable[][b].x = aPos.x
      pTable[][b].y = aPos.y
      idSet.excl(b)
    else:
      pTable[][a].x = initState[a].x
      pTable[][a].y = initState[a].y

proc calcWiggle[S,pT](initState: S, pTable: pT, temp: float, maxAmt: wSize) =
  # Copies x,y values from initState to pTable with some amount
  # changed based on temperature
  # initState must have at least the same keys as varTable.
  # Both tables must have x,y properties
  # Mutates pTable in place
  for id, item in pTable[]:
    let amt = moveAmt(temp, maxAmt)
    item.x = initState[id].x + amt.x
    item.y = initState[id].y + amt.y

proc copyPositions[S,pT](initState: S, pTable: pT) = 
  # Just copy the positions
  for id, item in pTable[]:
    item.x = initState[id].x
    item.y = initState[id].y

proc makeSwapper*[S,pT](): PerturbFn[S,pT] =
  calcSwap[S,pT]

proc makeWiggler*[S,pT](screenSize: wSize): PerturbFn[S,pT] =
  let moveScale = 0.5
  let maxAmt: wSize = ((screenSize.width.float  * moveScale).int,
                       (screenSize.height.float * moveScale).int)
  result = proc(initState: S, pTable: pT, temp: float) =
    calcWiggle(initState, pTable, temp, maxAmt)

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

proc update(hwnd: HWND, delay: int) = 
  # Sends update message and waits for response
  echo "update: Posting"
  PostMessage(hwnd, USER_ALG_UPDATE.UINT, 0, 0)
  echo "update: Receiving ack"
  let rx = gAckChan.recv()
  echo "Update: Received ack: ", rx
  if delay > 0:
    sleep(delay)


proc annealMain*(arg: AnnealArg) {.thread.} =
  # Do main anneal function
  var best25: Table[float, PosTable]
  var bestEver: tuple[heur: float, table: PosTable]
  var heur: float
  var done: bool = false
  let update = proc(delay: int = 0) = update(arg.window.mHwnd, delay)

  if arg.strategy == Strat1:
    discard
  elif arg.strategy == Strat2:
    {.gcsafe.}: arg.compactFn()
  
  var interState = arg.pRectTable[].positions
  var perturbedPositions: PosTable

  for temp in arange(MaxTemp .. MinTemp, TempStep):
    if best25.len > 0:
      let chosenHeur = selectHeuristic(best25.keys.toSeq) # Choose random with heuristic bias
      interState = best25[chosenHeur]
      best25.clear()

    # These could be done in parallel
    for i in 1..NumNextStates:
      echo i
      withLock(gLock):
        copyPositions(interState, arg.pRectTable)
        #echo "here 7", &" {temp}:{i}"
      #   gSendChan.send("Original")
      # update()
      # withLock(gLock):
        arg.perturbFn(interState, arg.pRectTable, temp)
        # echo "here 8", &" {temp}:{i}"
        echo "anneaMain: sending"
        gSendChan.send("Perturbed")
        echo "anneaMain: sent"
      echo "annealMain: updating A"
      update()
      echo "annealMain: updated A"
      echo "annealMain: locking"
      withLock(gLock):
        echo "annealMain: locked"
        #let perturbedPositions = arg.pRectTable[].positions
        perturbedPositions = arg.pRectTable[].positions
        # echo "here 9", &" {temp}:{i}"
        done = perturbedPositions == interState
        # echo "here 10", &" {temp}:{i}"
        if done: 
          break
        echo "annealMain: compacting"
        {.gcsafe.}: arg.compactFn()
        echo "annealMain: compacted"
      #   gSendChan.send("Compacted")
      #   echo "here 13", &" {temp}:{i}"
      # update()
      # echo "here 14", &" {temp}:{i}"
      # withLock(gLock):
        heur = arg.pRectTable[].fillRatio
        if heur > bestEver.heur:
          echo &"new best at {temp}: {heur}"
          bestEver = (heur, arg.pRectTable[].positions) # <-- compactPositions
        capturePos(best25, perturbedPositions, heur)
      echo "annealMain: updating B"
      update()
      echo "annealMain: updated B"
    
    
    
    update()

  # Set positions
  withLock(gLock):
    for id, pos in bestEver.table:
      arg.pRectTable[][id].x = pos.x
      arg.pRectTable[][id].y = pos.y
    echo arg.pRectTable[].fillRatio
  gSendChan.send(&"Final {bestEver.heur:.5}")
  update()
  echo "Annealing done"

    