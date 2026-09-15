import std/tables

import directions
from world import WType

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
    CurrentTempChanged,           # Float
    CompactReq                    # CompactRequest


# Define the types of things that go across the pubsub mechanism
type
  Signal* = object          # Empty data to satisfy one of the Signal topics
  CompactRequest* = object  # Sent by dialog box to satisfy the CompactReq topic
    direction*: CompactDir
    minSpaceX*: WType
    minSpaceY*: WType
    compactMethod*: CompactMethod
    annealStrategy*: StrategyOption
    replacementFunction*: ReplacementOption
    startTemp*: float
    doMonitor*: bool
  AnotherRequest* = object  # Placeholder to satisfy some other tbd topic
    placeholder1*: int
    placeholder2*: float
    placeholder3*: string

    
type
  Listener*[T] = proc(data: T) {.closure.}
  PubSub[K, T] = Table[K, seq[Listener[T]]]

var
  gPubSubEvent:          PubSub[CompactDlgPubSubTopic, Signal]
  gPubSubInt:            PubSub[CompactDlgPubSubTopic, int]
  gPubSubFloat:          PubSub[CompactDlgPubSubTopic, float]
  gPubSubCompactRequest: PubSub[CompactDlgPubSubTopic, CompactRequest]

template tableFor(T: typedesc): untyped =
  # Paste in the table for a given data type
  when T is Signal:          gPubSubEvent
  elif T is int:             gPubSubInt
  elif T is float:           gPubSubFloat
  elif T is CompactRequest:  gPubSubCompactRequest
  else: {.error: "No pubsub channel registered for type " & $T.}

proc soleTopic*(t: typedesc[CompactRequest]): CompactDlgPubSubTopic = CompactReq

# Generic registration that takes any topic and any data type
# example: psAddListener(someJunkId, proc(data: SomeType) = echo data
proc psAddListener*[K, T](topic: K, listener: Listener[T]): Listener[T] {.discardable.} =
  tableFor(T).mgetOrPut(topic, @[]).add(listener)
  listener

# Specific registration for signals that don't carry data, ie buttons
# example: psAddListener(Test, proc() = echo "Test signal received")
proc psAddListener*[K](topic: K, listener: proc() {.closure.}): proc() {.closure.} {.discardable.} =
  psAddListener(topic, proc(data: Signal) = listener())
  listener

# Specific registration for sole-topic data, eg CompactRequest
# example: psAddListener(proc(data: CompactRequest) = echo data)
proc psAddListener*[T](listener: Listener[T]): Listener[T] {.discardable.}=
  psAddListener(soleTopic(T), listener)
  listener


  


# Generic publish that takes any topic and any data type
# example: publish(someJunkId, someData)
proc publish*[K, T](topic: K, data: T) =
  if topic in tableFor(T): #.listeners:
    #for listener in tableFor(T).listeners[topic]:
    for listener in tableFor(T)[topic]:
      listener(data)

# Specific publish for signals that don't carry data
# example: publish(Test)
proc publish*(topic: CompactDlgPubSubTopic) =
  publish(topic, Signal())

# Specific publish for soletopic data, eg CompactRequest
# example: publish(myCompactRequest)
proc publish*[T](data: T) =
  publish(soleTopic(T), data)
