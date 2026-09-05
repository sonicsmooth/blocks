import std/tables
import usermessages
import pubsubtypes
export usermessages, pubsubtypes

type
  Listener*[T] = proc(data: T) {.closure.}
  PubSub[K, T] = object
    listeners: Table[K, seq[Listener[T]]]

# No longer exported -- publish/registerListener are the only public surface now.
var
  gPubSubEvent:          PubSub[CompactDlgPubSubTopic, Signal]
  gPubSubInt:            PubSub[CompactDlgPubSubTopic, int]
  gPubSubFloat:          PubSub[CompactDlgPubSubTopic, float]
  gPubSubCompactRequest: PubSub[CompactDlgPubSubTopic, CompactRequest]

template tableFor(T: typedesc): untyped =
  when T is Signal:          gPubSubEvent
  elif T is int:             gPubSubInt
  elif T is float:           gPubSubFloat
  elif T is CompactRequest:  gPubSubCompactRequest
  else: {.error: "No pubsub channel registered for type " & $T.}

proc soleTopic*(t: typedesc[CompactRequest]): CompactDlgPubSubTopic = CompactReq

# Generic registration that takes any topic and any data type
# example: registerListener(someJunkId, proc(data: SomeType) = echo data
proc registerListener*[K, T](topic: K, listener: Listener[T]) =
  tableFor(T).listeners.mgetOrPut(topic, @[]).add(listener)

# Specific registration for signals that don't carry data, ie buttons
# example: registerListener(Test, proc() = echo "Test signal received")
proc registerListener*[K](topic: K, listener: proc() {.closure.}) =
  registerListener(topic, proc(data: Signal) = listener())

# Specific registration for sole-topic data, eg CompactRequest
# example: registerListener(proc(data: CompactRequest) = echo data)
proc registerListener*[T](listener: Listener[T]) =
  registerListener(soleTopic(T), listener)

# Generic publish that takes any topic and any data type
# example: publish(someJunkId, someData)
proc publish*[K, T](topic: K, data: T) =
  if topic in tableFor(T).listeners:
    for listener in tableFor(T).listeners[topic]:
      listener(data)

# Specific publish for signals that don't carry data
# example: publish(Test)
proc publish*(topic: CompactDlgPubSubTopic) =
  publish(topic, Signal())

# Specific publish for soletopic data, eg CompactRequest
# example: publish(myCompactRequest)
proc publish*[T](data: T) =
  publish(soleTopic(T), data)
