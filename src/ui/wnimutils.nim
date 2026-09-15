import std/[os, 
            strformat]

from world import PxSize, PxPoint

import uicommon
import wnim
import winim

type
  MARGINS = object
    cxLeftWidth, cxRightWidth, cyTopHeight, cyBottomHeight: cint

# winim's dwmapi module may already declare DwmSetWindowAttribute for the
# dark-titlebar trick; if not, or if the newer constant is missing, just add it:
proc DwmSetWindowAttribute(hwnd: HWND, dwAttribute: DWORD,
                            pvAttribute: pointer, cbAttribute: DWORD): HRESULT
  {.importc, stdcall, dynlib: "dwmapi.dll".}
proc DwmExtendFrameIntoClientArea(hwnd: HWND, pMarInset: ptr MARGINS): HRESULT
  {.importc, stdcall, dynlib: "dwmapi.dll".}

proc enableAcrylic*(frame: wFrame) =
  const
    DWMWA_SYSTEMBACKDROP_TYPE = 38
    DWMSBT_MAINWINDOW      = 2'i32   # Mica — main app windows
    DWMSBT_TRANSIENTWINDOW = 3'i32   # Acrylic — dialogs, flyouts, menus (this is what you want)
  var backdrop = DWMSBT_TRANSIENTWINDOW
  let hr = DwmSetWindowAttribute(frame.handle, DWMWA_SYSTEMBACKDROP_TYPE,
                                 addr backdrop, sizeof(int32).DWORD)
  echo "setattribute result: ", hr

proc extendFrameIntoClientArea*(frame: wFrame) =
  var margins = MARGINS(cxLeftWidth: -1, cxRightWidth: -1,
                         cyTopHeight: -1, cyBottomHeight: -1)
  let hr = DwmExtendFrameIntoClientArea(frame.handle, addr margins)
  echo "extend frame result: ", hr



template paramSplit*(x: LPARAM|WPARAM): auto =
  (LOWORD(x).WORD,  HIWORD(x).WORD)


converter toSize*(size: wSize): PxSize = (size.width, size.height)
converter toPxPoint*(pt: wPoint): PxPoint = (pt.x, pt.y)

proc derefAs*[T](event: wEvent): T =
  # Event's wparam and lparam are both parts of a 64-bit
  # pointer-to-object.  Return the object.
  # The object is usually string (or cstring?)
  # TODO: check if we need both WP and LP since
  # TODO: each of these is machine-word size, ie 64 bit
  let
    wp = event.mWparam.int64
    lp = event.mLparam.int64
  cast[ptr T]((wp shl 32) or lp)[]

proc displayParams*(event: wEvent) =
  # Do stuff with param values
  # Show full decimal, then hex, then signed decimal
  # WPARAM and LPARAM are int64, but only the bottom
  # 32 bits get filled
  let
    wp = event.mWparam
    lp = event.mLparam
    wpuhi = (wp.shr(16).uint16)
    wpulo = (wp.uint16)
    wpshi = cast[int16](wpuhi)
    wpslo = cast[int16](wpulo)

    lpuhi = (lp.shr(16).uint16)
    lpulo = (lp.uint16)
    lpshi = cast[int16](lpuhi)
    lpslo = cast[int16](lpulo)
  stdout.write(&"wparam: 0x{wpuhi:04x}_{wpulo:04x} -> ({wpslo}, {wpshi}), ")
  stdout.write(&"lparam: 0x{lpuhi:04x}_{lpulo:04x} -> ({lpslo}, {lpshi})")
  stdout.write('\n')

proc appDpiScale*[T:(int, int)](value: T): T =
  let d = wAppGetDpi()
  (value[0] * d div 96, value[1] * d div 96)

proc appDpiScale*(value: int): int =
  value * wAppGetDpi() div 96

# Don't call wAppGetDpi() before the framework has initialized
# Otherwise the value returned is 96, which is probably not what you want


proc fontDescent*(font: wFont): int =
  let hdc = GetDC(0)
  let old = SelectObject(hdc, font.getHandle())
  var tm: TEXTMETRICW
  discard GetTextMetricsW(hdc, addr tm)
  discard SelectObject(hdc, old)
  discard ReleaseDC(0, hdc)
  result = tm.tmDescent

proc setBitmap*(ctrl: wCheckBox, bmp: wBitmap) =
  discard SendMessage(ctrl.handle, BM_SETIMAGE, IMAGE_BITMAP.WPARAM, bmp.handle.LPARAM)

proc barHeight*(): int =
  appDpiScale(gButtHeightRaw + 2 * gVmargRaw)

proc requiredSize*[T: wPanel](self: T, ignore: openArray[wControl]=[], addButtonSpace: bool=true): wSize =
  # After layout() has positioned everything, find the true extent of the controls
  # Optionally add a space at the bottom for Done button, etc.
  mixin wControl

  var maxRight, maxBottom: int
  for name, ctrl in self[].fieldPairs:
    when ctrl is wControl:
      if ctrl.isNil:
        discard
      elif ctrl in ignore:
        discard
      else:
        maxRight = max(maxRight, ctrl.position.x + ctrl.size.width)
        maxBottom = max(maxBottom, ctrl.position.y + ctrl.size.height)
  result = (maxRight, maxBottom)
  result.width += appDpiScale(gHmargRaw)
  if addButtonSpace:
    result.height += barHeight() + appDpiScale(gVmargRaw)

proc dumpLayout*[T: wPanel](self: T) =
  # write x,y,w,h of all widgets
  
  # workaround to issues using fieldPairs in a generic proc (#12423)
  # otherwise use template dumpLayout*(self: typed) =
  mixin wControl 
  
  let path = getAppDir() / "../src/ui/layouts" / $self.typeof & ".layout"
  when defined(debug):
    stdout.write "dumping layout to ", path, "..."
  var f = open(path, fmwrite)
  defer: close(f)
  for name, ctrl in self[].fieldPairs:
    when ctrl is wControl:
      if not ctrl.isNil:
        f.writeLine("self.", name, ".position = ", $ctrl.position, ".wPoint")
        f.writeLine("self.", name, ".size = ", $ctrl.size, ".wSize")
  when defined(debug):
    stdout.writeLine "done"

