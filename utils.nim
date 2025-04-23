import std/[strformat, bitops]
import wnim/wTypes
from winim import LOWORD, HIWORD
import sdl2
import rects

type
  SDLException = object of CatchableError


proc colordiv*(color: Color, num: uint8): Color =
  # Div only the RGB.
  result.r = color.r div num
  result.g = color.g div num
  result.b = color.b div num
  echo color, " -> ", result

template towColor*(r: untyped, g: untyped, b: untyped): wColor =
      wColor(wColor(r and 0xff)         or 
            (wColor(g and 0xff) shl  8) or
            (wColor(b and 0xff) shl 16))

proc toRGBA*(color: sdl2.Color): uint32 =
  bitor(color.r.shl(24),
        color.g.shl(16),
        color.b.shl( 8),
        color.a.shl( 0))

proc toBGRA*(color: sdl2.Color): uint32 =
  bitor(color.b.shl(24),
        color.g.shl(16),
        color.r.shl( 8),
        color.a.shl( 0))

proc toARGB*(color: sdl2.Color): uint32 =
  bitor(color.a.shl(24),
        color.r.shl(16),
        color.g.shl( 8),
        color.b.shl( 0))

proc toABGR*(color: sdl2.Color): uint32 =
  bitor(color.a.shl(24),
        color.b.shl(16),
        color.g.shl( 8),
        color.r.shl( 0))

# Todo: remove and(0xff)
template alpha(color: wColor|uint32): uint8 = color.shr(24).and(0xff).uint8
template red(color: wColor|uint32): uint8 = color.shr(16).and(0xff).uint8
template green(color: wColor|uint32): uint8 = color.shr( 8).and(0xff).uint8
template blue(color: wColor|uint32): uint8 = color.shr( 0).and(0xff).uint8
template rbswap*(color: wColor|uint32): uint32 =
  block:
    let rr = color.red.uint32.shl( 0)
    let gg = color.green.uint32.shl( 8)
    let bb = color.blue.uint32.shl(16)
    bitor(bb,gg,rr)

template SDLColor*(color: wColor|uint32, alpha: uint8 = 0xff): sdl2.Color =
  (r: color.red, g: color.green, b: color.blue, a: alpha)

template lParamTuple*[T](event: wEvent): auto =
  (LOWORD(event.getlParam).T,
   HIWORD(event.getlParam).T)


template SDLRect*(rect: rects.Rect|wRect): sdl2.Rect =
  # Not sure why I can't label the tuple elements with x:, y:, etc.
  (rect.x.cint, 
   rect.y.cint, 
   rect.width.cint,
   rect.height.cint)

template SDLPoint*(pt: wPoint): sdl2.Point =
  (pt.x.cint, pt.y.cint)

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
  result &= &"rmask : {rects.rmask:08x}\n"
  result &= &"rmaskx: {rmaskx:08x}\n"
  result &= &"gmask : {rects.gmask:08x}\n"
  result &= &"gmaskx: {gmaskx:08x}\n"
  result &= &"bmask : {rects.bmask:08x}\n"
  result &= &"bmaskx: {bmaskx:08x}\n"
  result &= &"amask : {rects.amask:08x}\n"
  result &= &"amaskx: {amaskx:08x}"
