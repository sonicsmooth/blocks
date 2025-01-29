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


proc nextStates*(table: RectTable, temp: float, screenSize: wSize) =
  # Take existing state and generate next states
  echo temp
  let currentState = positions(table)
  type StateType = Table[RectID, wPoint]
  var nextStates: seq[StateType]
  for i in 1..NUM_NEXT_STATES:
    var nextState: StateType
    for id, pos in currentState:
      nextState[id] = pos + moveAmt(temp, screenSize)
    nextStates.add(nextState)

  # quick test -- use the first new state to update the rect pos
  for id, pos in nextStates[0]:
    table[id].x = pos.x
    table[id].y = pos.y
