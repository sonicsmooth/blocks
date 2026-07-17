import std/[
            monotimes,
            segfaults, 
            strformat,
            tables,
            times ]
import editor, renderer
from std/sequtils import toSeq
import wNim
import winim except PRECT, Color
import sdl2
import rects, recttable, sdlframes
import userMessages, utils, appopts, routing, reporting

# TODO: blockpanel should have refs to editor, renderer, doc, viewport

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
 

var k,m: int
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

  proc processUIMouseMoveEvent*(self: wBlockPanel, event: wEvent) = 
    # Repackage specific event types and send to editor
    # Send mouse message for x,y position displayed in Frame
    # Maybe get rid of this and resend from editor somehow
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hWnd, idMsgMouseMove, event.wParam, event.lParam)
    self.editor.processMouseMoveEvent(event)

  proc processUIMouseWheelEvent*(self: wBlockPanel, event: wEvent) =
    self.editor.processMouseWheelEvent(event)

  proc processUIMouseButtonEvent*(self: wBlockPanel, event: wEvent) =
    if event.eventType == wEvent_LeftDown:
      echo "focus"
      SetFocus(self.mHwnd)
    self.editor.processMouseButtonEvent(event)

  proc onResize*(self: wBlockPanel, event: wEvent) =
    if self.isReady():
      self.editor.viewport.clientSize = event.size # should invoke converter
      self.editor.updateDestinationBox()
    event.skip()

  proc onPaint(self: wBlockPanel, event: wEvent) =
    if self.editor != nil:
      if gAppOpts.enableBbox:
        #! Move this to somewhere else
        self.editor.updateBoundingBox()
    if self.renderer != nil:
      let start = getMonoTime()
      self.renderer.drawEverything()
      let elapsed_ms = (getMonoTime() - start).inMilliseconds
      echo $elapsed_ms & " milliseconds"
  
  proc onFirstPaintKick(self: wBlockPanel) = 
      self.stopTimer()
      self.refresh(true)
      self.setFocus()

  proc init*(self: wBlockPanel, parent: wWindow) = 
    when defined(debug):
      echo "blockpanel init"
    initSDL()
    wSDLPanel(self).init(parent, style=wBorderSimple)

    self.wEvent_Size                 do (event: wEvent): flushEvents(0,uint32.high); self.onResize(event)
    self.wEvent_Paint                do (event: wEvent): flushEvents(0,uint32.high); self.onPaint(event)
    self.wEvent_MouseMove            do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseMoveEvent(event)
    self.wEvent_LeftDown             do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseButtonEvent(event)
    self.wEvent_LeftUp               do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseButtonEvent(event)
    self.wEvent_LeftDoubleClick      do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseButtonEvent(event)
    self.wEvent_MiddleDown           do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseButtonEvent(event)
    self.wEvent_MiddleUp             do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseButtonEvent(event)
    self.wEvent_MiddleDoubleClick    do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseButtonEvent(event)
    self.wEvent_RightDown            do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseButtonEvent(event)
    self.wEvent_RightUp              do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseButtonEvent(event)
    self.wEvent_RightDoubleClick     do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseButtonEvent(event)
    self.wEvent_MouseWheel           do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseWheelEvent(event)
    self.wEvent_MouseHorizontalWheel do (event: wEvent): flushEvents(0,uint32.high); self.processUIMouseWheelEvent(event)
    self.wEvent_KeyDown              do (event: wEvent): flushEvents(0,uint32.high); self.processUIKeyEvent(event)
    self.wEvent_KeyUp                do (event: wEvent): flushEvents(0,uint32.high); self.processUIKeyEvent(event)
    self.wEvent_Timer                do (): self.onFirstPaintKick()
    self.startTimer(0.0)
    