import std/locks

var
  gLock*: Lock
  gSendChan*: Channel[bool]
  gAckChan*: Channel[bool]

proc init*() = 
  gLock.initLock()
  gSendChan.open()
  gAckChan.open()

proc deinit*() =
  gLock.deinitLock()
  gSendChan.close()
  gAckChan.close()



