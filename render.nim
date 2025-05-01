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


proc font(rect: rects.Rect): FontPtr =
  # Return properly sized font ptr
  let px = min(rect.size.width, rect.size.height)
  let scaledSize = (px.float * fontScale).round.int
  let size = clamp(scaledSize, fontRange)
  if size notin fontCache:
    fontCache[size] = openFont("fonts/DejaVuSans.ttf", size)
  fontCache[size]

proc font(size: int): FontPtr =
  # Return properly sized font ptr
  let size = clamp(size, fontRange)
  if size notin fontCache:
    fontCache[size] = openFont("fonts/DejaVuSans.ttf", size)
  fontCache[size]

proc renderRect*(renderer: RendererPtr, rect: rects.Rect, sel: bool) =
  # Draw rectangle on SDL2 renderer
  # Draw main filled rectangle with outline
  let (w, h) = (rect.width, rect.height)
  let (ox, oy) = (rect.origin.x, rect.origin.y)
  let sdlRect = rect(0, 0, w, h)

  # Main rectangle
  renderer.setDrawColor(rect.brushColor.toColor())
  renderer.fillRect(addr sdlRect)

  # Outline
  renderer.setDrawColor(rect.penColor.toColor())
  renderer.drawRect(addr sdlRect)

  # Origin
  renderer.setDrawColor(colBlack.toColor())
  renderer.drawLine(ox-10, oy, ox+10, oy)
  renderer.drawLine(ox, oy-10, ox, oy+10)

  # Text to texture, then texture to renderer
  let selstr = $rect.id & (if sel: "*" else: "")
  let font = rect.font()
  let textSurface = font.renderUtf8Blended(selstr.cstring, colBlack.toColor())
  let (tsw, tsh) = (textSurface.w, textSurface.h)
  let dstRect: sdl2.Rect = ((w div 2) - (tsw div 2),
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
  let dstRect: sdl2.Rect = (sz.x - txtSzW - marg, 
                            sz.y - txtSzH - marg, 
                            txtSzW, txtSzH)
  let txtSurface = renderTextBlended(fnt, txt, colBlack.toColor())
  let txtTexture = renderer.createTextureFromSurface(txtSurface)
  discard renderer.copy(txtTexture, nil, addr dstRect)
  txtTexture.destroy()
  txtSurface.destroy()

proc renderBoundingBox*(renderer: RendererPtr, rect: sdl2.Rect, color: Color) = 
  # Assumes wRect and sdl2.Rect have same memory layout
  # Doesn't set drawcolor back to what it was
  renderer.setDrawColor(color)
  renderer.drawRect(cast [ptr sdl2.Rect](addr rect))

proc renderSelectionBox*(renderer: RendererPtr, rect: sdl2.Rect) =
  renderer.setDrawColor(0, 102, 204, 70)
  renderer.fillRect(addr rect)
  renderer.setDrawColor(0, 120, 215)
  renderer.drawRect(addr rect)


proc renderDestinationBox*(renderer: RendererPtr, rect: sdl2.Rect) =
  #let dstrect = SDLRect self.mDstRect
  renderer.setDrawColor(colRed.toColor())
  renderer.drawRect(addr rect)
