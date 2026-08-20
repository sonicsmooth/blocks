import std/[segfaults,
            #strformat,
            #strutils, 
            tables]

when defined(monotimeProfile):
  import std/[monotimes, times]

import wNim
import winim except PRECT

import editor
import rects
import recttable
import reporting
import renderer
#import routing
import sdlframes
import usermessages
import viewport

type
  wBlockPanel* = ref object of wSDLPanel
    editor*: Editor
    renderer*: Renderer

const
  keyTable: Table[int, KeyCode] =
    [
    (wKey_Esc,    KeyEsc   ),
    (wKey_Space,  KeySpace ),
    (wKey_Enter,  KeyEnter ),
    (wKey_Delete, KeyDelete),
    (wKey_Insert, KeyInsert),
    (wKey_Back,   KeyBack  ),
    (wKey_PgUp,   KeyPgUp  ),
    (wKey_PgDn,   KeyPgDn  ),
    (wKey_Ctrl,   KeyCtrl  ),
    (wKey_Shift,  KeyShift ),
    (wKey_Alt,    KeyAlt   ),
    (wKey_Up,     KeyUp    ),
    (wKey_Down,   KeyDn    ),
    (wKey_Left,   KeyLeft  ),
    (wKey_Right,  KeyRight ),
    (wKey_A,      KeyA     ),
    (wKey_B,      KeyB     ),
    (wKey_C,      KeyC     ),
    (wKey_D,      KeyD     ),
    (wKey_E,      KeyE     ),
    (wKey_F,      KeyF     ),
    (wKey_G,      KeyG     ),
    (wKey_H,      KeyH     ),
    (wKey_I,      KeyI     ),
    (wKey_J,      KeyJ     ),
    (wKey_K,      KeyK     ),
    (wKey_L,      KeyL     ),
    (wKey_M,      KeyM     ),
    (wKey_N,      KeyN     ),
    (wKey_O,      KeyO     ),
    (wKey_P,      KeyP     ),
    (wKey_Q,      KeyQ     ),
    (wKey_R,      KeyR     ),
    (wKey_S,      KeyS     ),
    (wKey_T,      KeyT     ),
    (wKey_U,      KeyU     ),
    (wKey_V,      KeyV     ),
    (wKey_W,      KeyW     ),
    (wKey_X,      KeyX     ),
    (wKey_Y,      KeyY     ),
    (wKey_Z,      KeyZ     ),
    (wKey_0,      Key0     ),
    (wKey_1,      Key1     ),
    (wKey_2,      Key2     ),
    (wKey_3,      Key3     ),
    (wKey_4,      Key4     ),
    (wKey_5,      Key5     ),
    (wKey_6,      Key6     ),
    (wKey_7,      Key7     ),
    (wKey_8,      Key8     ),
    (wKey_9,      Key9     )
    ].toTable
 

wClass(wBlockPanel of wSDLPanel):
  proc isReady*(self: wBlockPanel): bool =
    if self.editor.isNil: return reportNil("blockPanel.editor")
    if self.renderer.isNil: return reportNil("blockPanel.renderer")
    if not self.editor.isReady(): return reportNotReady("blockPanel.editor")
    if not self.renderer.isReady(): return reportNotReady("blockPanel.renderer")
    true
  proc mouseClientPosition*(self: wBlockPanel): PxPoint =
    self.screenToClient(wGetMousePosition())
  proc mouseWorldPosition*(self: wBlockPanel): WPoint =
    self.mouseClientPosition().toWorld(self.editor.viewport)

  proc processUIKeyEvent*(self: wBlockPanel, event: wEvent) = 
    # We don't deal with standalone modifier key events
    if event.keyCode == wKey_Ctrl or
       event.keyCode == wKey_Shift or
       event.keyCode == wKey_Alt: # also the mainframe captures alt and shift-alt before it gets here
        discard
    elif event.getEventType == wEvent_KeyDown:
      if self.isReady():
        if not keyTable.hasKey(event.keyCode): return
        let editorKeyCode = keyTable[event.keyCode]
        let editorKey: Key = (editorKeyCode, event.ctrlDown, event.altDown, event.shiftDown)
        self.editor.processKeyDown(editorKey)
    elif event.getEventType == wEvent_KeyUp:
      discard

  proc fillMouse(self: wBlockPanel, event: wEvent): MouseEvt =
    result = (pos: event.mousePos,
              kind: mekNone,
              btnLeft: event.leftDown,
              btnMid: event.middleDown,
              btnRight: event.rightDown,
              button: mbNone,
              edgeDir: mbdirNone,
              ctrl: event.ctrlDown,
              alt: event.altDown,
              shift: event.shiftDown,
              wheelDelta: event.wheelRotation,
              )

  proc processUIMouseMoveEvent*(self: wBlockPanel, event: wEvent) = 
    # Repackage specific event types and send to editor
    # Send mouse message for x,y position displayed in Frame
    # Maybe get rid of this and resend from editor somehow
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, idMsgMouseMove, event.wParam, event.lParam)
    self.editor.processMouseMoveEvent(self.fillMouse(event))

  proc processUIMouseButtonEvent*(self: wBlockPanel, event: wEvent) =
    if event.eventType == wEvent_LeftDown:
      SetFocus(self.mHwnd)
    var mouseEvt = self.fillMouse(event)
    case event.eventType
    of wEvent_LeftDown:
      mouseEvt.kind = mekDown
      mouseEvt.button = mbLeft
      mouseEvt.edgeDir = mbDirDown
    of wEvent_MiddleDown:
      mouseEvt.kind = mekDown
      mouseEvt.button = mbMid
      mouseEvt.edgeDir = mbDirDown
    of wEvent_RightDown:
      mouseEvt.kind = mekDown
      mouseEvt.button = mbRight
      mouseEvt.edgeDir = mbDirDown
    of wEvent_LeftUp:
      mouseEvt.kind = mekUp
      mouseEvt.button = mbLeft
      mouseEvt.edgeDir = mbDirUp
    of wEvent_MiddleUp:
      mouseEvt.kind = mekUp
      mouseEvt.button = mbMid
      mouseEvt.edgeDir = mbDirUp
    of wEvent_RightUp:
      mouseEvt.kind = mekUp
      mouseEvt.button = mbRight
      mouseEvt.edgeDir = mbDirUp
    of wEvent_LeftDoubleClick:
      mouseEvt.kind = mekDbl
      mouseEvt.button = mbLeft
    of wEvent_MiddleDoubleClick:
      mouseEvt.kind = mekDbl
      mouseEvt.button = mbMid
    of wEvent_RightDoubleClick: 
      mouseEvt.kind = mekDbl
      mouseEvt.button = mbRight

    else: return
    self.editor.processMouseClickEvent(mouseEvt)

  proc processUIMouseWheelEvent*(self: wBlockPanel, event: wEvent) =
    var mouseEvt = self.fillMouse(event)
    # event.wheelRotation doesn't work with horiz, so take wparam directly
    let wp = event.wParam.uint  # make sure this is at least 32 bits wide, not truncated
    let hiword = uint16((wp shr 16) and 0xFFFF)
    mouseEvt.wheelDelta = cast[int16](hiword)
    if event.eventType == wEvent_MouseWheel:
      mouseEvt.kind = mekWheelVert
    elif event.eventType == wEvent_MouseHorizontalWheel:
      mouseEvt.kind = mekWheelHoriz
    self.editor.processMouseWheelEvent(mouseEvt)

  proc onResize*(self: wBlockPanel, event: wEvent) =
    if self.isReady():
      self.editor.viewport.resize(event.size) # should invoke converter
      self.editor.doFitCheck()
      self.editor.updateDestinationBox()
    event.skip()

  when defined(loopProfile):
    var lastPaintTime: MonoTime

  proc onPaint(self: wBlockPanel, event: wEvent) =
    when defined(monotimeProfile):
      let now = getMonoTime()
      let lpt_ms = (now - lastPaintTime).inMilliseconds
      lastPaintTime = now

    when defined(monotimeProfile):
      let t0_render = getMonoTime()
    self.renderer.renderEverything()
    when defined(monotimeProfile):
      let renderTime_us = (getMonoTime() - t0_render).inMicroseconds 


    when defined(monotimeProfile):
      var s: string
      s = s & "last: " & $lpt_ms & " ms; "
      s = s & "render: " & $renderTime_us & " us; "
      echo s


  proc onTimer(self: wBlockPanel, event: wEvent) = 
    if event.timerId == 1:
      self.stopTimer(event.timerId)
      self.refresh(true)
      self.setFocus()
    elif event.timerID == 2:
      self.refresh(true)


  proc init*(self: wBlockPanel, parent: wWindow) = 
    when defined(debug):
      echo "blockpanel init"
    wSDLPanel(self).init(parent, style=wBorderSimple)

    self.wEvent_Size                 do (event: wEvent): self.onResize(event)
    self.wEvent_Paint                do (event: wEvent): self.onPaint(event)
    self.wEvent_MouseMove            do (event: wEvent): self.processUIMouseMoveEvent(event)
    self.wEvent_LeftDown             do (event: wEvent): self.processUIMouseButtonEvent(event)
    self.wEvent_LeftUp               do (event: wEvent): self.processUIMouseButtonEvent(event)
    self.wEvent_LeftDoubleClick      do (event: wEvent): self.processUIMouseButtonEvent(event)
    self.wEvent_MiddleDown           do (event: wEvent): self.processUIMouseButtonEvent(event)
    self.wEvent_MiddleUp             do (event: wEvent): self.processUIMouseButtonEvent(event)
    self.wEvent_MiddleDoubleClick    do (event: wEvent): self.processUIMouseButtonEvent(event)
    self.wEvent_RightDown            do (event: wEvent): self.processUIMouseButtonEvent(event)
    self.wEvent_RightUp              do (event: wEvent): self.processUIMouseButtonEvent(event)
    self.wEvent_RightDoubleClick     do (event: wEvent): self.processUIMouseButtonEvent(event)
    self.wEvent_MouseWheel           do (event: wEvent): self.processUIMouseWheelEvent(event)
    self.wEvent_MouseHorizontalWheel do (event: wEvent): self.processUIMouseWheelEvent(event)
    self.wEvent_KeyDown              do (event: wEvent): self.processUIKeyEvent(event)
    self.wEvent_KeyUp                do (event: wEvent): self.processUIKeyEvent(event)
    self.wEvent_Timer                do (event: wEvent): self.onTimer(event)
    self.startTimer(0.0,   id=1) # one-shot to start
    self.startTimer(1/60.0, id=2) # ongoing timer for refresh
    