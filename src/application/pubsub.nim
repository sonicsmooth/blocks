import std/tables

import directions
from world import WType, PxType

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
    Test, RandAll, RandPos, Undo, # Signals only -- no data type
    QtyRequest, QtyChanged,       # Integers
    SelectedChanged,              # Integer
    RegionXRequest, RegionXChanged,  # Integers
    RegionYRequest, RegionYChanged,  # Integers
    RegionWRequest, RegionWChanged,  # Integers
    RegionHRequest, RegionHChanged,  # Integers 
    StartTempRequest, CurrTempChanged,           # Floats
    CompactReq                    # CompactRequest
  AnotherDlgPubSubTopic* = enum DpsJunk1, DpsJunk2, DpsJunk3

  # Define the types of things that go across the pubsub mechanism
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


proc soleTopic*(t: typedesc[CompactRequest]): CompactDlgPubSubTopic = CompactReq

# Generic registration that takes any topic and any data type
# example: psAddListener(someJunkId, proc(data: SomeType) = echo data)
proc psAddListener*[K, T](topic: K, listener: Listener[T]): Listener[T] {.discardable.} =
  topicTable(K, T).mgetOrPut(topic, @[]).add(listener)
  listener

# Specific registration for signals that don't carry data, ie buttons
# example: psAddListener(Test, proc() = echo "Test signal received")
proc psAddListener*[K](topic: K, listener: proc() {.closure.}): proc() {.closure.} {.discardable.} =
  psAddListener(topic, proc(data: Event) = listener())
  listener

# Specific registration for sole-topic data, eg CompactRequest
# example: psAddListener(proc(data: CompactRequest) = echo data)
proc psAddListener*[T](listener: Listener[T]): Listener[T] {.discardable.}=
  psAddListener(soleTopic(T), listener)
  listener


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
