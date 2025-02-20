import std/locks
import wnim/private/wtypes
import rects

type
  AnnealThreadArg* = tuple[initState: PosTable, 
                           pRectTable: ptr RectTable, 
                           screenSize: wSize, 
                           compactfn: proc(),
                           showfn: proc()]
  RandomThreadArg* = tuple[prt: ptr RectTable, 
                           prep: proc(), 
                           refresh: proc()]

var
  gLock*: Lock
  gCond*: Cond
  gSendChan*: Channel[bool]
  gAckChan*: Channel[bool]
  # gJunkThread*: Thread[void]
  gRandomThread*: Thread[RandomThreadArg]
  # gAnnealThread*: Thread[ThreadArg]


proc init*() =
  initLock(gLock)
  initCond(gCond)
  open(gSendChan)
  open(gAckChan)

proc deinit*() = 
  deinitLock(gLock)
  deinitCond(gCond)
  close(gSendChan)
  close(gAckChan)