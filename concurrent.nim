import std/locks
import wnim/private/wtypes
import rects


type
  CompactFn* = proc()
  PrepFn* = proc()
  RefreshFn* = proc()
  RandomArg* = tuple[pRectTable: ptr RectTable,
                     window: wWindow]
  AnnealArg* = tuple[initState: PosTable,
                     pRectTable: ptr RectTable,
                     compactfn: CompactFn,
                     screenSize: wSize,
                     window: wWindow
                     #showfn: RefreshFn
                     ]

var
  gLock*: Lock
  gSendChan*: Channel[bool]
  gAckChan*: Channel[bool]
  gRandomThread*: Thread[RandomArg]
  gAnnealThread*: Thread[AnnealArg]


proc init*() = 
  gLock.initLock()
  gSendChan.open()
  gAckChan.open()

proc deinit*() =
  gLock.deinitLock()
  gSendChan.close()
  gAckChan.close()



