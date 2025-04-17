import bitops
import wnim/wTypes
import sdl2

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

