import sdl2
import colors

converter toSdlColor*(c: colors.ColorRGBA): sdl2.Color =
  result.r = c.r
  result.g = c.g
  result.b = c.b
  result.a = c.a