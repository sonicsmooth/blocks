import pixie
import colors

converter toPixieColorRGBA*(c: colors.ColorRGBA): pixie.ColorRGBA {.inline.} =
  pixie.rgba(c.r, c.g, c.b, c.a)

converter toPixieColorFloat*(c: colors.ColorRGBA): pixie.Color {.inline.} =
  let cf = c.toColorFloat()
  pixie.color(cf.r, cf.g, cf.b, cf.a)

converter toPixieColorFloat(c: colors.ColorFloat): pixie.Color {.inline.} =
  pixie.color(c.r, c.g, c.b, c.a)
