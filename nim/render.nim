import std/[tables, math, sequtils, strformat, sugar, macros]
import timeit
from wNim/wTypes import wSize
import sdl2
import sdl2/ttf
import rects, utils


type
  FontTable = Table[int, FontPtr]

const
  fontRange: Slice[int] = 6..24
  fontScale = 0.45
  defFontSize = 20

var
  fontCache: FontTable # Filled in as needed

proc font(size: int): FontPtr =
  # Return properly sized font ptr from cache based on size
  let clampSize = clamp(size, fontRange)
  if clampSize notin fontCache:
    fontCache[clampSize] = openFont("fonts/DejaVuSans.ttf", clampSize)
  fontCache[clampSize]

proc font(rect: rects.Rect): FontPtr =
  # Return properly sized font ptr from cache based on rect size
  let px = min(rect.size.w, rect.size.h)
  let scaledSize = (px.float * fontScale).round.int
  font(scaledSize)


proc renderRect*(renderer: RendererPtr, rect: rects.Rect, sel: bool) =
  # Draw rectangle on SDL2 renderer
  # Draw main filled rectangle with outline
  let (w, h) = (rect.w, rect.h)
  let (ox, oy) = (rect.origin.x, rect.origin.y)
  let sdlRect = rect(0, 0, w, h)

  # Main rectangle
  renderer.setDrawColor(rect.brushColor.toColor())
  renderer.fillRect(addr sdlRect)

  # Outline
  renderer.setDrawColor(rect.penColor.toColor())
  renderer.drawRect(addr sdlRect)

  # Origin
  renderer.setDrawColor(Black.toColor())
  renderer.drawLine(ox-10, oy, ox+10, oy)
  renderer.drawLine(ox, oy-10, ox, oy+10)

  # Text to texture, then texture to renderer
  let selstr = $rect.id & (if sel: "*" else: "")
  let font = rect.font()
  let textSurface = font.renderUtf8Blended(selstr.cstring, Black.toColor())
  let (tsw, tsh) = (textSurface.w, textSurface.h)
  let dstRect: PRect = ((w div 2) - (tsw div 2),
                            (h div 2) - (tsh div 2), tsw, tsh)
  let textTexture = renderer.createTextureFromSurface(textSurface)
  renderer.copy(textTexture, nil, addr dstRect)
  textTexture.destroy()

proc renderRect*(surface: SurfacePtr, rect: rects.Rect, sel: bool) =
  let renderer = createSoftwareRenderer(surface)
  renderer.renderRect(rect, sel)

proc renderText*(renderer: RendererPtr, window: WindowPtr, txt: string) =
  # Draws text at bottom right corner
  var txtSzW, txtSzH: cint
  let fnt = font(defFontSize)
  let sz = window.getSize()
  let marg = 10
  
  discard sizeText(fnt, txt, addr txtSzW, addr txtSzH)
  let dstRect: PRect = (sz.x - txtSzW - marg, 
                            sz.y - txtSzH - marg, 
                            txtSzW, txtSzH)
  let txtSurface = renderTextBlended(fnt, txt, Black.toColor())
  let txtTexture = renderer.createTextureFromSurface(txtSurface)
  discard renderer.copy(txtTexture, nil, addr dstRect)
  txtTexture.destroy()
  txtSurface.destroy()

proc renderBoundingBox*(renderer: RendererPtr, rect: PRect) = 
  # Assumes wRect and PRect have same memory layout
  # Doesn't set drawcolor back to what it was
  renderer.setDrawColor(Black.toColor())
  renderer.drawRect(cast [ptr PRect](addr rect))

proc renderSelectionBox*(renderer: RendererPtr, rect: PRect) =
  renderer.setDrawColor(0, 102, 204, 70)
  renderer.fillRect(addr rect)
  renderer.setDrawColor(0, 120, 215)
  renderer.drawRect(addr rect)

proc renderDestinationBox*(renderer: RendererPtr, rect: PRect) =
  renderer.setDrawColor(Red.toColor())
  renderer.drawRect(addr rect)
