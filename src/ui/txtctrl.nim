from std/strutils import strip
import pubsub
import utils
import wNim

type
  TextPublisher*[T] = proc(value: T) {.closure.}

proc onTextFocus*[T:wWindow](self: T, event: wEvent) = 
  cast[wTextCtrl](event.window).setInsertionPointEnd()
  event.skip()

proc onTextEdit*[T:wWindow](self: T, event: wEvent, K: typedesc) =
  const
    errBg = 0xcec7ff
    errFg = 0x06009
  let
    txtCtrl = cast[wTextCtrl](event.window)
  if parseNumber[K](txtCtrl.value.strip()).isSome():
    txtCtrl.backgroundColor = 0xffffff
    txtCtrl.foregroundColor = 0x000000
  else:
    txtCtrl.backgroundColor = errBg
    txtCtrl.foregroundColor = errFg

proc onTextCommit*[T:wWindow](self: T, event: wEvent, K: typedesc, announce: TextPublisher) =
  # Only qty, x, y, w, h need to get sent when text is entered
  # min spacing is sent with the arrow buttons
  let txtCtrl = cast[wTextCtrl](event.window)
  let valopt = parseNumber[K](txtCtrl.value.strip())
  if valopt.isSome():
    announce(valopt.get())
  else:
    echo "not commiting: \"", txtCtrl.value, "\""

proc onKillFocus*[T:wWindow](self: T, event: wEvent, K: typedesc, announce: TextPublisher) =
  onTextCommit(self, event, K, announce)
  event.skip()

template wireTextCtrl*(self: typed, txtCtrl: wTextCtrl, K: typedesc, announce: TextPublisher) =
  txtCtrl.wEvent_SetFocus  do (event: wEvent): onTextFocus(self, event)
  txtCtrl.wEvent_KillFocus do (event: wEvent): onKillFocus(self, event, K, announce)
  txtCtrl.wEvent_Text      do (event: wEvent): onTextEdit(self, event, K)
  txtCtrl.wEvent_TextEnter do (event: wEvent): onTextCommit(self, event, K, announce)