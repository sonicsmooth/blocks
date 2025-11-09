import std/[strformat]
import wnim/wTypes
from winim import LOWORD, HIWORD, DWORD, WORD, WPARAM, LPARAM
import sdl2
import rects
import colors
export colors

type
  SDLException = object of CatchableError


template paramSplit*(x: LPARAM|WPARAM): auto =
  (LOWORD(x).WORD,
   HIWORD(x).WORD)

proc derefAs*[T](event: wEvent): T =
  # Event's wparam and lparam are both parts of 64-bit
  # pointer-to-string.  Return the string
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



proc excl*[T](s: var seq[T], item: T) =
  # Remove all instances of an item from a sequence
  # Not order preserving because it uses del
  # Use delete to preserve order
  while item in s:
    s.del(s.find(item))

template sdlFailIf*(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())

proc textureInfo*(texture: TexturePtr): string =
  var pxfmt, rmaskx,gmaskx,bmaskx,amaskx: uint32
  var access, w, h, bpp: cint
  queryTexture(texture, addr pxfmt, addr access, addr w, addr h)
  discard pixelFormatEnumToMasks(pxfmt,bpp,rmaskx,gmaskx,bmaskx,amaskx)
  result &= &"format: {getPixelFormatName(pxfmt)}\n"
  result &= &"rmask : {colors.rmask:08x}\n"
  result &= &"rmaskx: {rmaskx:08x}\n"
  result &= &"gmask : {colors.gmask:08x}\n"
  result &= &"gmaskx: {gmaskx:08x}\n"
  result &= &"bmask : {colors.bmask:08x}\n"
  result &= &"bmaskx: {bmaskx:08x}\n"
  result &= &"amask : {colors.amask:08x}\n"
  result &= &"amaskx: {amaskx:08x}"

