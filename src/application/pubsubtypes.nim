import directions
from world import WType
export directions

# Define the types of things that go across
# the pubsub mechanism

type
  # Dialog -> orchestrator
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

  # Orchestrator -> Dialog
  UpdateTemp* = object
    temp: float
  
  # Dialog <-> Editor
  RegionDefine* = object
    X*, Y*, W*, H*: WType



