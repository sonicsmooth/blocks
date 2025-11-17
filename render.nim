import std/[enumerate, strutils, strformat, tables, math]
import sdl2
import sdl2/ttf
import rects, utils, appopts


type
  FontTable = Table[int, FontPtr]

const
  fontRange: Slice[int] = 6..100  
  fontScale = 0.45
  defFontSize = 25

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

proc renderDBComp*(rp: RendererPtr, vp: Viewport, rect: DBComp, prect: PRect, zero: bool) =
  # Draw rectangle on SDL2 renderer
  # vp is Viewport, used for zoom
  # rect is database object
  # prect is target rectangle with same aspect ratio as rect
  # zero is whether the object should be rendered at upper left corner of target
  #   this should be true when target is texture
  #   this should be false when target is screen

  # Draw rectangle
  var err: SDL_Return
  let prect = 
    if zero: prect.zero # used by texture renderer
    else:    prect      # used by screen renderer

  let highlight =
    if   (rect.selected, rect.hovering) == (false, false): 1.0
    elif (rect.selected, rect.hovering) == (false, true ): 1.2
    elif (rect.selected, rect.hovering) == (true,  false): 1.5
    else: 1.9
  
  rp.renderFilledRect(prect, rect.fillColor * highlight, rect.penColor)
  when defined(debug):
    if err != SdlSuccess:
      raise newException(ValueError, &"Could not renderFilledRect: {getError()}")

  # Draw origin
  # Todo: There is something to be said here about model space
  # TODO: to world space to pixel space
  let
    fnx = proc(x: WType): PxType = (x.float * vp.zoom).round.cint
    fny = proc(y: WType): PxType = (y.float * vp.zoom).round.cint - 1
    opx: PxPoint = (fnx(rect.originToLeftEdge), fny(rect.originToTopEdge))
    extent = (10.0 * vp.zoom).round.cint
  rp.setDrawColor(Black.toColor)
  err = rp.drawLine(prect.x + opx.x - extent, prect.y + opx.y, prect.x + opx.x + extent, prect.y + opx.y)
  when defined(debug):
    if err != SdlSuccess:
      raise newException(ValueError, &"Could not drawLine: {getError()}")
  err = rp.drawLine(prect.x + opx.x, prect.y + opx.y - extent, prect.x + opx.x, prect.y + opx.y + extent)
  when defined(debug):
    if err != SdlSuccess:
      raise newException(ValueError, &"Could not drawLine: {getError()}")

  # Text to texture, then texture to renderer
  # TODO: cache texts at different sizes
  if gAppOpts.enableText:
    let 
      (w, h) = (prect.w, prect.h)
      selstr = $rect.id & (if rect.selected: "*" else: "")
      font = rect.font(vp.zoom)
      textSurface = font.renderUtf8Blended(selstr.cstring, Black.toColor)
      (tsw, tsh) = (textSurface.w, textSurface.h)
      dstRect: PRect = (prect.x + (w div 2) - (tsw div 2),
                        prect.y + (h div 2) - (tsh div 2), tsw, tsh)
      pTextTexture = rp.createTextureFromSurface(textSurface)
    if pTextTexture.isNil:
      raise newException(ValueError, &"Text Texture pointer is nil: {getError()}")

    rp.copyEx(pTextTexture, nil, addr dstRect, -rect.rot.toFloat, nil)
    pTextTexture.destroy()

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

proc renderText*(renderer: RendererPtr, x,y: cint, txt: string) =
  # Draws text at given location
  var txtSzW, txtSzH: cint
  let
    fnt = font(defFontSize)
    lines = txt.splitLines
    maxLine = longestLine(lines)

  discard sizeText(fnt, maxLine.cstring, addr txtSzW, addr txtSzH)
  txtSzH *= lines.len
  let dstRect: PRect = (x - txtSzW, y - txtSzH, txtSzW, txtSzH)
  let txtSurface = renderTextBlendedWrapped(fnt, txt, Black.toColor(), 0)
  let txtTexture = renderer.createTextureFromSurface(txtSurface)
  discard renderer.copy(txtTexture, nil, addr dstRect)
  txtTexture.destroy()
  txtSurface.destroy()

proc renderText*(renderer: RendererPtr, window: WindowPtr, txt: string) =
  # Draws text at bottom right corner
  renderer.renderText(window.getSize.x - 10,
                      window.getSize.y - 10, txt)







