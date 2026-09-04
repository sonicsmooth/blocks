import directions
from world import WType
export directions

# Define the types of things that go across
# the pubsub mechanism

type
  # Just use raw values for simple things like int, float
  # Placement Dialog -> Editor
  # NewQty = uint
  # Editor -> Placement Dialog
  # Selected = uint

  # No content, just the event
  Signal* = object

  # Placement Dialog -> Orchestrator
  CompactButton* = enum BtnTest, BtnRandAll, BtnRandPos
  CompactRequest* = object
    direction*: CompactDir
    minSpaceX*: WType
    minSpaceY*: WType
    compactMethod*: CompactMethod
    annealStrategy*: StrategyOption
    replacementFunction*: ReplacementOption
    startTemp*: float
    doMonitor*: bool

  # # Orchestrator -> Placement Dialog
  # UpdateTemp* = object
  #   temp: float
  
  # Placement Dialog <-> Editor
  RegionDefine* = object
    X*, Y*, W*, H*: WType






