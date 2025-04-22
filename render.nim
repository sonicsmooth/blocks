import std/[tables, math, sequtils, sugar]
from wNim/wTypes import wSize
import sdl2
import sdl2/ttf
import rects
import utils

type
  FontTable = Table[int, FontPtr]

const
  fontRange: Slice[int] = 6..24

var
  fonts: FontTable

echo fonts.keys.toSeq
for f in fonts.values:
  echo cast[int](f)

proc fontSize(size: wSize): int =
  # Return font size based on rect size
  # round to int
  let scale = 0.25
  let px = min(size.width, size.height)
  let spix:int = (px.float * scale).round.int
  clamp(spix, fontRange)

proc fontCache(rect: rects.Rect): FontPtr =
  let size = fontSize(rect.size)
  if size notin fonts:
    fonts[size] = openFont("fonts/DejaVuSans.ttf", size)
  fonts[size]

proc renderRect*(renderer: RendererPtr, rect: rects.Rect, sel: bool) =
  # Draw rectangle on SDL2 renderer
  # Draw main filled rectangle with outline
  let (w, h) = (rect.width, rect.height)
  let (ox, oy) = (rect.origin.x, rect.origin.y)
  let sdlRect = rect(0, 0, w, h)
  renderer.setDrawColor(SDLColor rect.brushcolor.rbswap)
  renderer.fillRect(addr sdlRect)
  renderer.setDrawColor(SDLColor rect.pencolor.rbswap)
  renderer.drawRect(addr sdlRect)
  renderer.setDrawColor(SDLColor 0)
  renderer.drawLine(ox-10, oy, ox+10, oy)
  renderer.drawLine(ox, oy-10, ox, oy+10)

  # Text to texture, then texture to renderer
  let selstr = $rect.id & (if sel: "*" else: "")
  let font = fontCache(rect)
  let textSurface = font.renderUtf8Blended(selstr.cstring, SDLColor 0)
  let (tsw, tsh) = (textSurface.w, textSurface.h)
  let dstRect: sdl2.Rect = ((w div 2) - (tsw div 2),
                            (h div 2) - (tsh div 2), tsw, tsh)
  let textTexture = renderer.createTextureFromSurface(textSurface)
  renderer.copy(textTexture, nil, addr dstRect)
  textTexture.destroy()


