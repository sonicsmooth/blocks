import compact
import pubsub

type Orchestrator = ref object
  myPlaceholder: bool


proc orchJunk*(data: CompactButton) = 
  case data:
  of BtnTest:    echo "application: testing"
  of BtnRandAll: echo "application: rand all"
  of BtnRandPos: echo "application: rand pos"
