import std/[math, segfaults, sets, sugar, strformat, tables ]
import editor, renderer
from std/sequtils import toSeq
import wNim
import winim except PRECT, Color
import sdl2
import rects, recttable, sdlframes, grid #, document, viewport, grid, pointmath
import userMessages, utils, appopts, routing

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
 
# proc isCtrl(event: wEvent): bool = event.keyCode == wKey_Ctrl
# proc isShift(event: wEvent): bool = event.keyCode == wKey_Shift
# proc isAlt(event: wEvent): bool = event.keyCode == wKey_Alt

wClass(wBlockPanel of wSDLPanel):
  proc forceRedraw*(self: wBlockPanel, wait: int = 0) = 
    #discard
    self.refresh(false)
    UpdateWindow(self.mHwnd)

  proc processUiEvent*(self: wBlockPanel, event: wEvent) = 
    # We don't deal with modifier key events directly
    if event.keyCode == wKey_Ctrl or
       event.keyCode == wKey_Shift or
       event.keyCode == wKey_Alt:
        return

    # Repackage specific event types and send to editor
    # Do all key processing first; all else is mouse state stuff
    if event.getEventType == wEvent_KeyDown:
      let editorKeyCode = keyTable[event.keyCode]
      let editorKey: Key = (editorKeyCode, event.ctrlDown, event.altDown, event.shiftDown)
      self.editor.processKeyDown(editorKey)
      return
    elif event.getEventType == wEvent_KeyUp:
      return

    # Send mouse message for x,y position displayed in Frame
    # Maybe get rid of this and resend from editor somehow
    if event.eventType == wEvent_MouseMove or
       event.eventType == wEvent_MouseWheel:
      let hWnd = GetAncestor(self.handle, GA_ROOT)
      SendMessage(hWnd, idMsgMouseMove, event.wParam, event.lParam)
      # let editorMouseEvent = MouseEvent(
      #   pos: event.mousePos,
      #   ctrl: event.ctrlDown,
      #   alt: event.altDown,
      #   shift: event.shiftDown,
      #   wheel: event.wheelRotation
      # )
      #self.editor.processMouseEvent(editorMouseEvent)
    if event.eventType == wEvent_LeftDown:
      SetFocus(self.mHwnd)
    self.editor.processMouseEvent(event)

  proc onResize*(self: wBlockPanel, event: wEvent) =
    self.editor.viewport.clientSize = event.size # should invoke converter
    self.editor.updateDestinationBox()

  proc onPaint(self: wBlockPanel, event: wEvent) =
    #discard
    if gAppOpts.enableBbox:
      self.editor.updateBoundingBox()
    self.renderer.drawEverything()
  

  proc init*(self: wBlockPanel, parent: wWindow) = 
    echo "blockpanel init"
    discard
    wSDLPanel(self).init(parent, style=wBorderSimple)
    self.backgroundColor = wLightBlue

    self.wEvent_Size                 do (event: wEvent): flushEvents(0,uint32.high);self.onResize(event)
    self.wEvent_Paint                do (event: wEvent): flushEvents(0,uint32.high);self.onPaint(event)
    self.wEvent_MouseMove            do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_LeftDown             do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_LeftUp               do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_LeftDoubleClick      do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_MiddleDown           do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_MiddleUp             do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_MiddleDoubleClick    do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_RightDown            do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_RightUp              do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_RightDoubleClick     do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_MouseWheel           do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_MouseHorizontalWheel do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_KeyDown              do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)
    self.wEvent_KeyUp                do (event: wEvent): flushEvents(0,uint32.high);self.processUiEvent(event)

    