import std/[strformat]
import wnim/wTypes
from winim import LOWORD, HIWORD
import sdl2
import rects
import colors
export colors

type
  SDLException = object of CatchableError



template lParamTuple*[T](event: wEvent): auto =
  (LOWORD(event.getlParam).T,
   HIWORD(event.getlParam).T)

proc excl*[T](s: var seq[T], item: T) =
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

