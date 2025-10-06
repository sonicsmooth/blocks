import std/[enumerate, strutils, tables, math, sugar]
import sdl2
import sdl2/ttf
import rects, utils, pointmath


type
  FontTable = Table[int, FontPtr]

const
  fontRange: Slice[int] = 6..100  
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

proc font(rect: DBComp, zoom: float): FontPtr =
  # Return properly sized font ptr from cache based on rect size
  let px = min(rect.bbox.w, rect.bbox.h)
  let scaledSize = (px.float * fontScale * zoom).round.int
  font(scaledSize)

proc renderFilledRect*(rp: RendererPtr, rect: PRect, fillColor, penColor: ColorU32) =
  # Draw PRect
  #let r: sdl2.Rect = (x: rect.x, y: rect.y, w: rect.w, h: rect.h)
  rp.setDrawColor(fillColor.toColor)
  rp.fillRect(addr rect)
  rp.setDrawColor(penColor.toColor)
  rp.drawRect(addr rect)

proc renderOutlineRect*(rp: RendererPtr, rect: PRect, penColor: ColorU32) =
  #let r: sdl2.Rect = (x: rect.x, y: rect.y, w: rect.w, h: rect.h)
  rp.setDrawColor(penColor.toColor)
  rp.drawRect(addr rect)

proc renderDBComp*(rp: RendererPtr, vp: ViewPort, rect: DBComp, zero: bool) =
  # Draw rectangle on SDL2 renderer
  # zero is whether the object should be rendered at upper left corner of target
  #   this should be true when target is texture
  #   this should be false when target is screen
  
  # Draw rectangle
  let prect = 
    if zero: rect.bbox.toPRect(vp).zero # used by texture renderer
    else:    rect.bbox.toPRect(vp)      # used by screen renderer

  if rect.hovering:
    rp.renderFilledRect(prect, rect.hoverColor, rect.penColor)
  else:
    rp.renderFilledRect(prect, rect.fillColor, rect.penColor)

  # Draw origin
  # Todo: There is something to be said here about model space
  # todo: to world space to pixel space
  let
    fnx = proc(x: WType): PxType = (x.float * vp.zoom).round.cint
    fny = proc(y: WType): PxType = (y.float * vp.zoom).round.cint - 1
    opx: PxPoint = (fnx(rect.originToLeftEdge), fny(rect.originToTopEdge))
    extent = (10.0 * vp.zoom).round.cint
  rp.setDrawColor(Black.toColor)
  rp.drawLine(prect.x + opx.x - extent, prect.y + opx.y, prect.x + opx.x + extent, prect.y + opx.y)
  rp.drawLine(prect.x + opx.x, prect.y + opx.y - extent, prect.x + opx.x, prect.y + opx.y + extent)

  # Text to texture, then texture to renderer
  when not defined(noText):
    let 
      (w, h) = (prect.w, prect.h)
      selstr = $rect.id & (if rect.selected: "*" else: "")
      font = rect.font(vp.zoom)
      textSurface = font.renderUtf8Blended(selstr.cstring, Black.toColor)
      (tsw, tsh) = (textSurface.w, textSurface.h)
      dstRect: PRect = (prect.x + (w div 2) - (tsw div 2),
                        prect.y + (h div 2) - (tsh div 2), tsw, tsh)
      textTexture = rp.createTextureFromSurface(textSurface)
    rp.copyEx(textTexture, nil, addr dstRect, -rect.rot.toFloat, nil)
    textTexture.destroy()

proc longestLine(lines: openArray[string]): string =
  # Returns longest substring terminated by newline
  var
    maxLen: int
    maxi: int
  for i, line in enumerate(lines):
    if line.len > maxLen:
      maxLen = line.len
      maxi = i
  lines[maxi]

proc renderText*(renderer: RendererPtr, window: WindowPtr, txt: string) =
  # Draws text at bottom right corner
  var txtSzW, txtSzH: cint
  let
    fnt = font(defFontSize)
    sz = window.getSize()
    marg = 10
    lines = txt.splitLines
    maxLine = longestLine(lines)

  discard sizeText(fnt, maxLine, addr txtSzW, addr txtSzH)
  txtSzH *= lines.len
  let dstRect: PRect = (sz.x - txtSzW - marg, 
                        sz.y - txtSzH - marg, 
                        txtSzW, txtSzH)
  #let txtSurface = renderTextBlended(fnt, txt, Black.toColor())
  let txtSurface = renderTextBlendedWrapped(fnt, txt, Black.toColor(), 0)
  let txtTexture = renderer.createTextureFromSurface(txtSurface)
  discard renderer.copy(txtTexture, nil, addr dstRect)
  txtTexture.destroy()
  txtSurface.destroy()




