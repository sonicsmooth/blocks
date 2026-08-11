
import std/[math,
            strformat,
            tables
            ]
import sdl2 except Color
import sdl2/ttf
import appopts
import colors, colors_sdl
import common
import rotation
import rects


proc highlight(selected, hovering: bool): float =
  if   (selected, hovering) == (false, false): 1.0
  elif (selected, hovering) == (false, true ): 1.2
  elif (selected, hovering) == (true,  false): 1.5
  else: 1.9

proc drawOutlineRectSDL(rp: RendererPtr, rect: PRect, penColor: ColorRGBA) =
  # explicit convertion to SDL2.Rect?
  rp.setDrawColor(penColor)
  rp.drawRect(addr rect)

proc renderCompOriginSDL(rp: RendererPtr, comp: DBComp, prect: PRect, vp: Viewport, rot: bool) =
  # Todo: There is something to be said here about model space
  # TODO: to world space to pixel space
  # Pass rot to origin..edge functions.
  # When rot is false, everything is treated as an unrotated component
  # The opx here is identical to comp.rotationPoint(vp) when rot is false
  # There appears to be a -1 in here for some reason
  let
    fnx = proc(x: WType): PxType = (x.float * vp.zoom).round.cint
    fny = proc(y: WType): PxType = (y.float * vp.zoom).round.cint - 1
    opx: PxPoint = (fnx(comp.originToLeftEdge(rot)), fny(comp.originToTopEdge(rot)))
    extent = (10.0 * vp.zoom).round.cint
  rp.setDrawColor(Black)
  rp.drawLine(prect.x + opx.x - extent, prect.y + opx.y, prect.x + opx.x + extent, prect.y + opx.y)
  rp.drawLine(prect.x + opx.x, prect.y + opx.y - extent, prect.x + opx.x, prect.y + opx.y + extent)

proc drawFilledOutlineRectSDL*(rp: RendererPtr, rect: PRect, fillColor, penColor: ColorRGBA) =
  # explicit convertion to SDL2.Rect?
  rp.setDrawColor(fillColor)
  rp.fillRect(addr rect)
  rp.setDrawColor(penColor)
  rp.drawRect(addr rect)

proc renderCompTextSDL(rp: RendererPtr, comp: DBComp, font: FontPtr, prect: PRect, rot: bool) =
  # Render component text
  # Text to texture, then texture to renderer surface.
  # This gets converted back to texture again after return
  # So this could clearly be optimized and assembled when
  # creating cache
  if font.isNil:
    return
  let 
    (w, h) = (prect.w, prect.h)
    selstr = $comp.id
    textSurface = font.renderUtf8Blended(selstr.cstring, Black)
  let textTexture = rp.createTextureFromSurface(textSurface)
  let
    (tsw, tsh) = (textSurface.w, textSurface.h)
    texRect: PRect = (prect.x + (w div 2) - (tsw div 2),
                      prect.y + (h div 2) - (tsh div 2), tsw, tsh)
  if textTexture.isNil:
    raise newException(ValueError, &"Text Texture pointer is nil: {getError()}")

  if rot:
    rp.copyEx(textTexture, nil, addr texRect, comp.rot.toFloat, nil)
  else:
    rp.copyEx(textTexture, nil, addr texRect, 0, nil)
  textSurface.destroy()
  textTexture.destroy()

proc renderDBCompSDL*(rp: RendererPtr, comp: DBComp, prect: PRect, vp: Viewport, hov, sel: bool, rot: bool) =
  # Draw rectangle, origin, and its text using SDL2 renderer to prect
  # prect is rectangle in pixels
  # hov, sel is whether this is hovering and/or selected
  # rot: true means use default rotated bbox and rotate text
  # rot: false means render as R0, with text unrotated, and box zero'd
  # Generally SDLDirect will use rot=true and false otherwise
  
  let 
    highlightFactor = highlight(hov, sel)
    font = font(comp, vp.zoom)
  rp.drawFilledOutlineRectSDL(prect, comp.fillColor * highlightFactor, comp.penColor)
  if sel:
    rp.drawOutlineRectSDL(prect.shrink(1), comp.penColor    )
    rp.drawOutlineRectSDL(prect.shrink(2), comp.penColor * 2)
    rp.drawOutlineRectSDL(prect.shrink(3), comp.penColor * 3)
    rp.drawOutlineRectSDL(prect.shrink(4), comp.penColor * 4)
  rp.renderCompOriginSDL(comp, prect, vp, rot)
  if gAppOpts.enableText:
    rp.renderCompTextSDL(comp, font, prect, rot)
