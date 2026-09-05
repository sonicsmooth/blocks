import directions
from world import WType
export directions

# Define the types of things that go across
# the pubsub mechanism

type
  # No content, just the event
  Signal* = object
  CompactRequest* = object
    direction*: CompactDir
    minSpaceX*: WType
    minSpaceY*: WType
    compactMethod*: CompactMethod
    annealStrategy*: StrategyOption
    replacementFunction*: ReplacementOption
    startTemp*: float
    doMonitor*: bool






