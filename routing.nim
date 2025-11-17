import std/[sets, tables]
from winim/inc/windef import WPARAM, LPARAM, HANDLE
from winim/inc/winuser import SendMessage
from wnim/private/wTypes import wWindow, wEvent
from wnim/private/wWindow import connect
import utils
import usermessages
export usermessages


type MsgProc* = proc(self: wWindow, event: wEvent) {.nimcall.}

# Any given message int maps to one or more targets
var gEventListeners = initTable[int, seq[HANDLE]]()

proc uniqueHandles(): HashSet[HANDLE] =
  # Return set of unique handles
  for handles in gEventListeners.values:
    for handle in handles:
      result.incl(handle)


proc registerListener*(listener: wWindow, msg: int32, callback: MsgProc) =
  if msg notin gEventListeners:
    gEventListeners[msg] = @[]
  gEventListeners[msg].add(listener.mHwnd)
  listener.connect(msg) do (event: wEvent): callback(listener, event)

proc deregisterListener*(listener: wWindow) = 
  var keysToDelete: seq[int32] = @[]
  let handle: HANDLE = listener.mHwnd
  for msg, handles in gEventListeners:
    if handle in handles:
      gEventListeners[msg].excl(handle)
      if gEventListeners[msg].len == 0:
        keysToDelete.add(msg)
  let cnt = keysToDelete.len
  for msg in keysToDelete:
    gEventListeners.del(msg)
  when defined(debug):
    echo "Deregistered ", cnt, " listeners"
    echo uniqueHandles().len, " handles left"

proc sendToListeners*(msg: int32, wp: WPARAM, lp: LPARAM) =
  # msg is the message
  # wp is usually the hwnd of the sender
  # lp is usually the value to be sent
  if msg notin gEventListeners:
    return
  for handle in gEventListeners[msg]:
    SendMessage(handle, msg, wp, lp)