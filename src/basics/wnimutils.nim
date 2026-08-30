import std/strformat
import wnim/wTypes


proc derefAs*[T](event: wEvent): T =
  # Event's wparam and lparam are both parts of a 64-bit
  # pointer-to-object.  Return the object.
  # The object is usually string (or cstring?)
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
