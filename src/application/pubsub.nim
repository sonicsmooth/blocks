import std/tables
import usermessages
import pubsubtypes
export usermessages, pubsubtypes

type
  Listener*[T] = proc(data: T) {.closure.}
  PubSub[K, T] = object
    listeners: Table[K, seq[Listener[T]]]

var
  gPubSubEvent*:          PubSub[MsgId, Signal]
  gPubSubCompactButtons*: PubSub[MsgId, CompactButton]
  gPubSubCompactRequest*: PubSub[MsgId, CompactRequest]

# A listener is a function that is assicated with a key
proc registerListener*[K, T](ps: var PubSub[K, T], key: K, listener: Listener[T]) =
  ps.listeners.mgetOrPut(key, @[]).add(listener)

proc registerListener*[K](ps: var PubSub[K, Signal], key: K, listener: proc() {.closure.}) =
  ps.registerListener(key, proc(data: Signal) = listener())

proc publish*[K, T](ps: var PubSub[K, T], key: K, data: T) =
  if key in ps.listeners:
    for listener in ps.listeners[key]:
      listener(data)

