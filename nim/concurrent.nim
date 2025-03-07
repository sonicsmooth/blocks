import std/locks

const
  numThreads* = 2

var
  #gCond*: Cond
  gLock*: Lock
  #gSendChan*: Channel[string]
  #gAckChan*: Channel[int]

proc init*() =
  #gCond.initCond() 
  gLock.initLock()
  #gSendChan.open(10)
  #gAckChan.open(10)

proc deinit*() =
  #gAckChan.close()
  #gSendChan.close()
  gLock.deinitLock()
  #gCond.deinitCond()

