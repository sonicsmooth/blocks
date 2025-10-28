import std/tables
from winim/inc/windef import WPARAM, LPARAM, HANDLE
from winim/inc/winuser import SendMessage
from wnim/private/wTypes import wWindow, wEvent
from wnim/private/wWindow import connect
import utils
import usermessages
export usermessages

#[
setup checkbox
mCbVisible.registerListener
mCbVisible.connect(wEvent_Checkbox) -> go through list and send messages to everyone
mCbVisible.connect(idMsgVisible) -> set checkbox state

setup toolbar
frame.registerListener
frame.connect(wToolbarEvent) -> 
  frame.onToolEvent
    case msg when visible: sendToListeners
frame.connect(idMsgVisible) -> set checkbox state

setup grid
frame.registerListener
frame.connect(idMsgVisible) -> set grid state in rebar.toolbar
]#

type MsgProc* = proc(self: wWindow, event: wEvent) {.nimcall.}

# Any given message int maps to one or more targets
var gEventListeners = initTable[int, seq[HANDLE]]()

proc registerListener*(listener: wWindow, msg: int32, callback: MsgProc) =
  if msg notin gEventListeners:
    gEventListeners[msg] = @[]
  gEventListeners[msg].add(listener.mHwnd)
  listener.connect(msg) do (event: wEvent): callback(listener, event)

proc deregisterListener*(listener: wWindow) = 
  var keysToDelete: seq[int32] = @[]
  let handle:HANDLE = listener.mHwnd
  when defined(debug):
    echo gEventListeners
  for msg, handles in gEventListeners:
    if handle in handles:
      gEventListeners[msg].excl(handle)
      if gEventListeners[msg].len == 0:
        keysToDelete.add(msg)
  for msg in keysToDelete:
    gEventListeners.del(msg)

proc sendToListeners*(msg: int32, wp: WPARAM, lp: LPARAM) =
  # msg is the message
  # wp is usually the hwnd of the sender
  # lp is usually the value to be sent
  if msg notin gEventListeners:
    return
  for handle in gEventListeners[msg]:
    SendMessage(handle, msg, wp, lp)