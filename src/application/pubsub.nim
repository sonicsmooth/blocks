import std/sequtils
import std/tables
import std/typetraits
import std/strutils

import directions
import utils
from world import WType, PxType
from rects import PxRect, WRect

#[
How PubSub works
A set of Topics (keys) looks up Listeners (proc) in a Channel (Table)
There are different tables for the different types that the procs accept
A topic is associated with exactly zero or one data type
A data type (such as float) is associated with >= 1 topics

When you need to send a signal only (no data), you can send the topic only:
  publish(Test)
  publish(RandAll)
  publish(RandPos)
  publish(Undo)

You can send an int or float like this:
  publish(Qty, 10)
  publish(RegionX, 12.3)

You can send a single-topic data like CompactRequest:
  publish(myCompactRequestObject)

]#


# Domain-specific keys (topics) for the pubsub mechanism
type
  CompactDlgTopic* = enum
    Test, RandAll, RandPos, Undo,      # Signals only -- no data type
    QtyRequest, QtyChanged,            # Integers
    SelectedChanged,                   # Integer
    RegionXRequest,   RegionXChanged,  # WType
    RegionYRequest,   RegionYChanged,  # WType
    RegionWRequest,   RegionWChanged,  # WType
    RegionHRequest,   RegionHChanged,  # WType
    RegionRequest,    RegionChanged,   # WRect
    StartTempRequest, CurrTempChanged, # Floats
    CompactReq                    # CompactRequest
  GridDlgTopic* = enum
    XRequest, XChanged,                     # Float
    DivRequest, DivChanged,                 # String
    MagRequest, MagChanged,                 # Float
    SnapRequest, SnapChanged,               # Bool
    DynamicRequest, DynamicChanged,         # Bool
    CoolZoomRequest, CoolZoomChanged,       # Bool
    VisibleRequest, VisibleChanged,         # Bool
    DotsorLinesRequest, DotsorLinesChanged, # Bool


  # Define some types of things that go across the pubsub mechanism
  # This is in addition to any other object that already exists
  # Such as int, float, PxRect, etc.
  Event* = object          # Empty data to satisfy one of the Event topics
  CompactRequest* = object  # Sent by dialog box to satisfy the CompactReq topic
    direction*: CompactDir
    minSpaceX*: WType
    minSpaceY*: WType
    compactMethod*: CompactMethod
    annealStrategy*: StrategyOption
    replacementFunction*: ReplacementOption
    startTemp*: float
    doMonitor*: bool

  # Define the types of listener tables
  Listener*[T] = proc(data: T) {.closure.}
  PubSubTable[K, T] = Table[K, seq[Listener[T]]]

var
  gCompactDlgEvents:      PubSubTable[CompactDlgTopic, Event]
  gCompactDlgInts:        PubSubTable[CompactDlgTopic, int]
  gCompactDlgInt32s:      PubSubTable[CompactDlgTopic, int32]
  gCompactDlgFloats:      PubSubTable[CompactDlgTopic, float]
  gCompactDlgPxRects:     PubSubTable[CompactDlgTopic, PxRect]
  gCompactDlgWRects:      PubSubTable[CompactDlgTopic, WRect]
  gCompactDlgCompactReqs: PubSubTable[CompactDlgTopic, CompactRequest]
  gGridDlgEvents:         PubSubTable[GridDlgTopic, Event]
  gGridDlgDotsOrLines:    PubSubTable[GridDlgTopic, DotsOrLines]
  gGridDlgBools:          PubSubTable[GridDlgTopic, bool]
  gGridDlgInts:           PubSubTable[GridDlgTopic, int]
  gGridDlgInt32s:         PubSubTable[GridDlgTopic, int32]
  gGridDlgFloats:         PubSubTable[GridDlgTopic, float]

template topicTable(K, T: typedesc): untyped =
  when K is CompactDlgTopic:
    when T is Event: gCompactDlgEvents
    elif T is int: gCompactDlgInts
    elif T is int32: gCompactDlgInt32s
    elif T is float: gCompactDlgFloats
    elif T is PxRect: gCompactDlgPxRects
    elif T is WRect: gCompactDlgWRects
    elif T is CompactRequest: gCompactDlgCompactReqs
    else: {.error: "No pubsub table for " & $K & "/" & $T.}
  elif K is GridDlgTopic:
    when T is Event: gGridDlgEvents
    elif T is DotsOrLines: gGridDlgDotsOrLines
    elif T is bool: gGridDlgBools
    elif T is int: gGridDlgInts
    elif T is int32: gGridDlgInt32s
    elif T is float: gGridDlgFloats
    else: {.error: "No pubsub table for " & $K & "/" & $T.}
  else:
    {.error: "No topic-kind registered for " & $K.}


template forEachTopicKind(T: typedesc, body: untyped) =
  block:
    type K {.inject.} = CompactDlgTopic
    when compiles(topicTable(K, T)):
      body
  block:
    type K {.inject.} = GridDlgTopic
    when compiles(topicTable(K, T)):
      body

proc tableLens[K, T](tname: string, table: PubSubTable[K, T], newline: bool = true): (string, int) =
  var s: string
  var t: int
  s = tname & (if newline: "\n" else: "")
  for topic, listeners in table:
    s &= "  " & $topic & ": " & $listeners.len & "\n"
    t += listeners.len
  result = (s, t)


proc psLens(): string =
  var totalListeners = 0
  var s, outstr: string
  var t, total: int
  (s, t) = tableLens("gCompactDlgEvents", gCompactDlgEvents); outstr &= s; total += t
  (s, t) = tableLens("gCompactDlgInts", gCompactDlgInts); outstr &= s; total += t
  (s, t) = tableLens("gCompactDlgInt32s", gCompactDlgInt32s); outstr &= s; total += t
  (s, t) = tableLens("gCompactDlgFloats", gCompactDlgFloats); outstr &= s; total += t
  (s, t) = tableLens("gCompactDlgPxRects", gCompactDlgPxRects); outstr &= s; total += t
  (s, t) = tableLens("gCompactDlgWRects", gCompactDlgWRects); outstr &= s; total += t
  (s, t) = tableLens("gCompactDlgCompactReqs", gCompactDlgCompactReqs); outstr &= s; total += t
  (s, t) = tableLens("gGridDlgEvents", gGridDlgEvents); outstr &= s; total += t
  (s, t) = tableLens("gGridDlgDotsOrLines", gGridDlgDotsOrLines); outstr &= s; total += t
  (s, t) = tableLens("gGridDlgBools", gGridDlgBools); outstr &= s; total += t
  (s, t) = tableLens("gGridDlgInts", gGridDlgInts); outstr &= s; total += t
  (s, t) = tableLens("gGridDlgInt32s", gGridDlgInt32s); outstr &= s; total += t
  (s, t) = tableLens("gGridDlgFloats", gGridDlgFloats, newline=false); outstr &= s; total += t
  echo outstr
  echo "Total listeners: ", total


proc soleTopic*(t: typedesc[CompactRequest]): CompactDlgTopic = CompactReq

# Generic registration that takes any topic and any data type
# example: psAddListener(someJunkId, proc(data: SomeType) = echo data)
proc psAddListener*[K, T](topic: K, listener: Listener[T]): Listener[T] {.discardable.} =
  topicTable(K, T).mgetOrPut(topic, @[]).add(listener)
  # echo "Adding Listener [", $K, ", ", $T, "]"
  # echo psLens()
  listener

# Specific registration for signals that don't carry data, ie buttons
# example: psAddListener(Test, proc() = echo "Test signal received")
proc psAddListener*[K](topic: K, listener: proc() {.closure.}): Listener[Event] {.discardable.} =
  psAddListener(topic, proc(data: Event) = listener())

# Specific registration for sole-topic data, eg CompactRequest
# example: psAddListener(proc(data: CompactRequest) = echo data)
proc psAddListener*[T](listener: Listener[T]): Listener[T] {.discardable.}=
  psAddListener(soleTopic(T), listener)


proc psRemoveListener*[T](listener: Listener[T]) =
  # Go through all topics
  # echo "Before"
  # echo psLens()
  forEachTopicKind(T):
    var pTable = topicTable(K, T).addr
    var emptyTopics: seq[K]
    for topic, listeners in pTable[].mpairs:
      listeners.excl(listener)
      if listeners.len == 0:
        emptyTopics.add(topic)
    for topic in emptyTopics:
      pTable[].del(topic)
  # echo "\nAfter"
  # echo psLens()

proc psRemoveListeners*[T](self: T) =
  for name, value in self[].fieldPairs:
    when value is Listener:
      # echo name
      psRemoveListener(value)



# Generic publish that takes any topic and any data type
# example: publish(someJunkId, someData)
proc publish*[K, T](topic: K, data: T) =
  if topic in topicTable(K, T):
    for listener in topicTable(K, T)[topic]:
      listener(data)

# Specific publish for signals that don't carry data
# example: publish(Test)
proc publish*(topic: CompactDlgTopic) =
  publish(topic, Event())

# Specific publish for soletopic data, eg CompactRequest
# example: publish(myCompactRequest)
proc publish*[T](data: T) =
  publish(soleTopic(T), data)

proc psStats*(): string =
  echo "gCompactDlgEvents: ", gCompactDlgEvents.len
  echo "gCompactDlgInts: ", gCompactDlgInts.len
  echo "gCompactDlgInt32s: ", gCompactDlgInt32s.len
  echo "gCompactDlgFloats: ", gCompactDlgFloats.len
  echo "gCompactDlgPxRects: ", gCompactDlgPxRects.len
  echo "gCompactDlgWRects: ", gCompactDlgWRects.len
  echo "gCompactDlgCompactReqs: ", gCompactDlgCompactReqs.len
  echo "gGridDlgEvents: ", gGridDlgEvents.len
  echo "gGridDlgDotsOrLines: ", gGridDlgDotsOrLines.len
  echo "gGridDlgBools: ", gGridDlgBools.len
  echo "gGridDlgInts: ", gGridDlgInts.len
  echo "gGridDlgInt32s: ", gGridDlgInt32s.len
  echo "gGridDlgFloats: ", gGridDlgFloats.len
