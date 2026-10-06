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
  CompactDlgPubSubTopic* = enum
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
  AnotherDlgPubSubTopic* = enum DpsJunk1, DpsJunk2, DpsJunk3

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
  DummyRequest* = object  # Placeholder to satisfy some other tbd topic
    placeholder1*: int
    placeholder2*: float
    placeholder3*: string

  # Define the types of listener tables
  Listener*[T] = proc(data: T) {.closure.}
  PubSubTable[K, T] = Table[K, seq[Listener[T]]]

var
  gPubSubEvents:          PubSubTable[CompactDlgPubSubTopic, Event]
  gPubSubInts:            PubSubTable[CompactDlgPubSubTopic, int]
  gPubSubInt32s:          PubSubTable[CompactDlgPubSubTopic, int32]
  gPubSubFloats:          PubSubTable[CompactDlgPubSubTopic, float]
  gPubSubPxRects:         PubSubTable[CompactDlgPubSubTopic, PxRect]
  gPubSubWRects:          PubSubTable[CompactDlgPubSubTopic, WRect]
  gPubSubCompactRequests: PubSubTable[CompactDlgPubSubTopic, CompactRequest]
  gPubSubDummyEvents:     PubSubTable[AnotherDlgPubSubTopic, Event]
  gPubSubDummyInts:       PubSubTable[AnotherDlgPubSubTopic, int]
  gPubSubDummyInt32s:     PubSubTable[AnotherDlgPubSubTopic, int32]
  gPubSubDummyFloats:     PubSubTable[AnotherDlgPubSubTopic, float]

template topicTable(K, T: typedesc): untyped =
  when K is CompactDlgPubSubTopic:
    when T is Event: gPubSubEvents
    elif T is int: gPubSubInts
    elif T is int32: gPubSubInt32s
    elif T is float: gPubSubFloats
    elif T is PxRect: gPubSubPxRects
    elif T is WRect: gPubSubWRects
    elif T is CompactRequest: gPubSubCompactRequests
    else: {.error: "No pubsub table for " & $K & "/" & $T.}
  elif K is AnotherDlgPubSubTopic:
    when T is Event: gPubSubDummyEvents
    elif T is int: gPubSubDummyInts
    elif T is int32: gPubSubDummyInt32s
    elif T is float: gPubSubDummyFloats
    else: {.error: "No pubsub table for " & $K & "/" & $T.}
  else:
    {.error: "No topic-kind registered for " & $K.}


template forEachTopicKind(T: typedesc, body: untyped) =
  block:
    type K {.inject.} = CompactDlgPubSubTopic
    when compiles(topicTable(K, T)):
      body
  block:
    type K {.inject.} = AnotherDlgPubSubTopic
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
  (s, t) = tableLens("gPubSubEvents", gPubSubEvents); outstr &= s; total += t
  (s, t) = tableLens("gPubSubInts", gPubSubInts); outstr &= s; total += t
  (s, t) = tableLens("gPubSubInt32s", gPubSubInt32s); outstr &= s; total += t
  (s, t) = tableLens("gPubSubFloats", gPubSubFloats); outstr &= s; total += t
  (s, t) = tableLens("gPubSubPxRects", gPubSubPxRects); outstr &= s; total += t
  (s, t) = tableLens("gPubSubWRects", gPubSubWRects); outstr &= s; total += t
  (s, t) = tableLens("gPubSubCompactRequests", gPubSubCompactRequests); outstr &= s; total += t
  (s, t) = tableLens("gPubSubDummyEvents", gPubSubDummyEvents); outstr &= s; total += t
  (s, t) = tableLens("gPubSubDummyInts", gPubSubDummyInts); outstr &= s; total += t
  (s, t) = tableLens("gPubSubDummyInt32s", gPubSubDummyInt32s); outstr &= s; total += t
  (s, t) = tableLens("gPubSubDummyFloats", gPubSubDummyFloats, newline=false); outstr &= s; total += t
  echo outstr
  echo "Total listeners: ", total


proc soleTopic*(t: typedesc[CompactRequest]): CompactDlgPubSubTopic = CompactReq

# Generic registration that takes any topic and any data type
# example: psAddListener(someJunkId, proc(data: SomeType) = echo data)
proc psAddListener*[K, T](topic: K, listener: Listener[T]): Listener[T] {.discardable.} =
  topicTable(K, T).mgetOrPut(topic, @[]).add(listener)
  echo "Adding Listener [", $K, ", ", $T, "]"
  echo psLens()
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
  echo "Before"
  echo psLens()
  forEachTopicKind(T):
    var pTable = topicTable(K, T).addr
    var emptyTopics: seq[K]
    for topic, listeners in pTable[].mpairs:
      listeners.excl(listener)
      if listeners.len == 0:
        emptyTopics.add(topic)
    for topic in emptyTopics:
      pTable[].del(topic)
  echo "\nAfter"
  echo psLens()

proc psRemoveListeners*[T](self: T) =
  for name, value in self[].fieldPairs:
    when value is Listener:
      echo name
      psRemoveListener(value)



# let myfn1 = proc(x: int) {.closure.} = echo "hi"
# let myfn2 = proc(x: int) {.closure.} = echo "bye"
# psAddListener(SelectedChanged, myfn1)
# # psAddListener(SelectedChanged, myfn2)
# # psAddListener(QtyRequest, myfn1)
# psRemoveListener(myfn1)
# # psRemoveListener(myfn2)
# # echo gPubSubInts.len

# Generic publish that takes any topic and any data type
# example: publish(someJunkId, someData)
proc publish*[K, T](topic: K, data: T) =
  if topic in topicTable(K, T):
    for listener in topicTable(K, T)[topic]:
      listener(data)

# Specific publish for signals that don't carry data
# example: publish(Test)
proc publish*(topic: CompactDlgPubSubTopic) =
  publish(topic, Event())

# Specific publish for soletopic data, eg CompactRequest
# example: publish(myCompactRequest)
proc publish*[T](data: T) =
  publish(soleTopic(T), data)

proc psStats*(): string =
  echo "gPubSubEvents: ", gPubSubEvents.len
  echo "gPubSubInts: ", gPubSubInts.len
  echo "gPubSubInt32s: ", gPubSubInt32s.len
  echo "gPubSubFloats: ", gPubSubFloats.len
  echo "gPubSubPxRects: ", gPubSubPxRects.len
  echo "gPubSubWRects: ", gPubSubWRects.len
  echo "gPubSubCompactRequests: ", gPubSubCompactRequests.len
  echo "gPubSubDummyEvents: ", gPubSubDummyEvents.len
  echo "gPubSubDummyInts: ", gPubSubDummyInts.len
  echo "gPubSubDummyInt32s: ", gPubSubDummyInt32s.len
  echo "gPubSubDummyFloats: ", gPubSubDummyFloats.len
