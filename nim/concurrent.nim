import std/locks
import wnim/private/wtypes
import rects


type
  CompactFn* = proc() {.closure.}
  AnnealFn*[S,pT] = proc(initState: S, pTable: pT, temp: float) {.closure.}
  RandomArg* = tuple[pRectTable: ptr RectTable,
                     window: wWindow]
  AnnealArg* = tuple[initState:  PosTable,
                     pRectTable: ptr RectTable,
                     annealFn:   AnnealFn[PosTable, ptr RectTable],
                     compactFn:  CompactFn,
                     window:     wWindow
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



