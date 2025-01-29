# Simulated annealing
import std/[random]
import wnim
import rects

const NUM_NEXT_STATES = 100
const MAX_TEMP = 100.0
# At each temperature generate 100 randomized next states
# The higher the temperature, the more each block moves around
# After gathering 100 next states, randomly choose the next
# starting state for the next temperature.  The random choice
# is actually weighted by the fitness of each next state.

proc moveAmt(temp: float, screenSize: wSize): wPoint =
  # At maximum temp, maximum move is wSize/2
  let halfWidth: float  = screenSize.width.float / 2.0
  let halfheight: float = screenSize.height.float / 2.0
  let maxX: float       = temp/100.0 * halfWidth
  let maxY: float       = temp/100.0 * halfHeight
  let xmv: int          = (rand(maxX) - halfWidth / 2).int
  let xmy: int          = (rand(maxY) - halfHeight / 2).int
  result = (xmv, xmy)




proc randomizeRectsPos*(table: RectTable, temp: float, screenSize: wSize) =
  # Take existing state and generate 
  echo moveAmt(temp, screenSize)
  # for id, rect in table:
  #   rect.x = rand(screenSize.width  - rect.width  - 1)
  #   rect.y = rand(screenSize.height - rect.height - 1)
