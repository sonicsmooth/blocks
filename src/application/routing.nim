import std/[sets, 
            tables]
from winim/inc/windef import WPARAM, LPARAM, HANDLE
from winim/inc/winuser import SendMessage, WM_USER
from wnim/private/wTypes import wWindow, wEvent
from wnim/private/wWindow import connect
import utils



# These are constant values that go across 
# threads or from one frame to another.
# a blaSend is sent from the dialog in question
# a blaRecv is received by the dialog in question

# There are a few message and ID types
# IDs for UI-specific messages used in SendMessage (received by a Window)
# Keys for the pubsub mechanism with domain data

type
  # Platform (UI)-specific message IDs for sending messages to windows
  MsgId* = enum
    woMouseMove, woSize, woSlider, woAlgUpdate,
    woGridZoom, woGridSizeX, woGridRequestX, woGridSizeY,
    woGridRequestY, woGridDivisionsSelect, woGridDivisionsValue,
    woGridDivisionsReset, woGridDensity, woGridSnap, woGridDynamic,
    woGridBaseSync, woGridVisible, woGridDots, woGridLines,
    woGCFDestroying, woPFDestroying

const
  # Get rid of these
  idMsgMouseMove*       = WM_USER + ord(woMouseMove)
  idMsgSize*            = WM_USER + ord(woSize)
  idMsgSlider*          = WM_USER + ord(woSlider)
  idMsgAlgUpdate*       = WM_USER + ord(woAlgUpdate)
  
  # Grid Control Frame
  idGCFZoom*            = WM_USER + ord(woGridZoom)
  idGCFSizeX*           = WM_USER + ord(woGridSizeX)
  idGCFRequestX*        = WM_USER + ord(woGridRequestX)
  idGCFSizeY*           = WM_USER + ord(woGridSizeY)
  idGCFRequestY*        = WM_USER + ord(woGridRequestY)
  idGCFDivisionsSelect* = WM_USER + ord(woGridDivisionsSelect)
  idGCFDivisionsValue*  = WM_USER + ord(woGridDivisionsValue)
  idGCFDivisionsReset*  = WM_USER + ord(woGridDivisionsReset)
  idGCFDensity*         = WM_USER + ord(woGridDensity)
  idGCFSnap*            = WM_USER + ord(woGridSnap)
  idGCFDynamic*         = WM_USER + ord(woGridDynamic)
  idGCFBaseSync*        = WM_USER + ord(woGridBaseSync)
  idGCFVisible*         = WM_USER + ord(woGridVisible)
  idGCFDots*            = WM_USER + ord(woGridDots)
  idGCFLines*           = WM_USER + ord(woGridLines)
  idGCFDestroying*         = WM_USER + ord(woGCFDestroying)
  
  # # Placement Frame
  idPFDestroying*    = WM_USER + ord(woPFDestroying)


  
  # Random thread stuff
  ALG_NO_INIT_BMP*  = 0
  ALG_INIT_BMP*     = 10



type MsgProc* = proc(self: wWindow, event: wEvent) {.nimcall.}

# Any given message int maps to one or more targets
var gEventListeners = initTable[int32, seq[HANDLE]]()

proc uniqueHandles(): HashSet[HANDLE] =
  # Return set of unique handles
  for handles in gEventListeners.values:
    for handle in handles:
      result.incl(handle)


proc registerListener*(listener: wWindow, msg: int32, callback: MsgProc) =
  # This makes window receive messages
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