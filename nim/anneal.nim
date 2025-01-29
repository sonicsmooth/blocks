# Simulated annealing
import std/[random]
import wnim
from wnim/private/wHelper import `+`
import rects

const NUM_NEXT_STATES = 10
const MAX_TEMP* = 100.0
# At each temperature generate 100 randomized next states
# The higher the temperature, the more each block moves around
# After gathering 100 next states, randomly choose the next
# starting state for the next temperature.  The random choice
# is actually weighted by the fitness of each next state.

proc moveAmt(temp: float, screenSize: wSize): wPoint =
  # At maximum temp, maximum move is wSize/2
  let halfWidth: float  = screenSize.width.float / 4.0
  let halfheight: float = screenSize.height.float / 4.0
  let maxX: float       = temp/100.0 * halfWidth
  let maxY: float       = temp/100.0 * halfHeight
  let xmv: int          = (rand(maxX) - maxX/2.0).int
  let xmy: int          = (rand(maxY) - maxY/2.0).int
  result = (xmv, xmy)

proc calcNextState[T:Table](startingState: T, temp: float, screenSize: wSize, i: int): T =
  # This one does random move
  # Perhaps another can do position swaps based on temperature
  # The next state need only return the items that were actually moved
  for id, pos in startingState:
    result[id] = pos + moveAmt(temp, screenSize)

iterator nextStates*[T:Table](startingState: T, temp: float, screenSize: wSize): T =
  # Yield next states from existing state
  for i in 1..NUM_NEXT_STATES:
    yield calcNextState(startingState, temp, screenSize, i)

