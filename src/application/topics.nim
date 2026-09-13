
# Domain-specific keys (topics) for the pubsub mechanism
type
  CompactDlgPubSubTopic* = enum
    Test, RandAll, RandPos, Undo,                    # Signals
    Qty, Selected,                                   # Integers
    RegionX, RegionY, RegionW, RegionH, CurrentTemp, # Floats
    CompactReq                                       # CompactRequest
  # SignalTopic* = range[Test..Undo]
    
