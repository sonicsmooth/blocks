
import std/[math,
            options,
            os,
            tables
            ]
import sdl2 except Color
import sdl2/ttf

import appopts
import colors
import sdlcolors
import common
import rotation
import rects
import viewport

const
  gFontScale = 0.45

var
  gFontCache: Table[int, FontPtr]
  gFontName: Option[string]

proc tryFont(size: float): FontPtr =
  for p in fontCandidates():
    if isNone(gFontName) and not fileExists(p):
      echo "Could not find ", p
      continue
    result = ttf.openFont(p.cstring, size.round.cint)
    if not result.isNil:
      if gFontName.isNone:
        gFontName = some(p)
        echo "SDL Loaded ", p, " with size ", size
      return result

# TODO: see whether other places need this, not just components
proc font*(size: cint): FontPtr =
  # Return properly sized font ptr from cache based on size
  if size notin gFontCache:
    gFontCache[size] = tryFont(size)
  gFontCache[size]

proc font*(comp: DBComp, zoom: float): FontPtr =
  # Return properly sized font ptr from cache based on comp size
  let wbb = comp.wbbox
  let fsz = min(wbb.w, wbb.h).float
  let scaledSize = (fsz * gFontScale * zoom).round.int.clamp(fontRange)
  font(scaledSize)

proc clearFontCache*() = 
  for f in gFontCache.values:
    f.close() # is this equivalent to destroy in other objects?
  gFontCache.clear()

proc drawFilledOutlineRectSDL*(rp: RendererPtr, rect: PRect, fillColor, penColor: ColorRGBA) =
  rp.setDrawColor(fillColor)
  rp.fillRect(addr rect)
  rp.setDrawColor(penColor)
  rp.drawRect(addr rect)

proc highlight(selected, hovering: bool): float =
  if   (selected, hovering) == (false, false): 1.0
  elif (selected, hovering) == (false, true ): 1.2
  elif (selected, hovering) == (true,  false): 1.5
  else: 1.9

proc drawSolid(rp: RendererPtr, rect: PRect, fillColor, penColor: ColorRGBA) =
  rp.setDrawColor(fillColor)
  rp.fillRect(addr rect)

proc drawBorder(rp: RendererPtr, rect: PRect, color: ColorRGBA, hov, sel: bool) =
  if not hov and not sel:
    rp.setDrawColor(color)
    rp.drawRect(addr rect)
  elif hov and not sel:
    let r1 = rect.shrink(0)
    let r2 = rect.shrink(1)
    rp.setDrawColor(color)
    rp.drawRect(addr r1)
    rp.setDrawColor(color)
    rp.drawRect(addr r2)
  elif sel:
    let r1 = rect.shrink(0)
    let r2 = rect.shrink(1)
    let r3 = rect.shrink(2)
    rp.setDrawColor(color)
    rp.drawRect(addr r1)
    rp.setDrawColor(color)
    rp.drawRect(addr r2)
    rp.setDrawColor(color)
    rp.drawRect(addr r3)

proc drawCompText(rp: RendererPtr, comp: DBComp, prect: PRect, zoom: float, rot: bool) =
  # Render component text to surface->texture->renderer
  let 
    fnt = font(comp, zoom)
    (w, h) = (prect.w, prect.h)
    textSurface = fnt.renderUtf8Blended(($comp.id).cstring, comp.penColor)
    textTexture = rp.createTextureFromSurface(textSurface)
    (tsw, tsh) = (textSurface.w, textSurface.h)
    texRect: PRect = (prect.x + (w div 2) - (tsw div 2),
                      prect.y + (h div 2) - (tsh div 2), tsw, tsh)
    rotAmt = if rot: -comp.rot.toFloat else: 0.0
  rp.copyEx(textTexture, nil, addr texRect, rotAmt, nil)
  textSurface.destroy()
  textTexture.destroy()

proc drawOrigin(rp: RendererPtr, comp: DBComp, prect: PRect, zoom: float, rot: bool) =
  # When rot is false/true, everything is treated as an un/rotated component
  # The opx here is identical to comp.rotationPoint(vp) when rot is false
  # There appears to be a -1 in here for some reason, I think when you're measuring
  # from the opposite side, ie origin-to-top, you have to adjust.
  # Here we check against distance to top edge because we want y=0 to 
  # be at maximum pixels away from the top
  let extent = (10.0 * zoom).round.cint
  var opx = comp.originToTopLeft(rot).toPixelScale(zoom)
  if gAppOpts.oneOffset:
    opx.y -= 1
  rp.setDrawColor(Black)
  rp.drawLine(prect.x + opx.x - extent, prect.y + opx.y, prect.x + opx.x + extent, prect.y + opx.y)
  rp.drawLine(prect.x + opx.x, prect.y + opx.y - extent, prect.x + opx.x, prect.y + opx.y + extent)

proc renderDBCompSDL*(rp: RendererPtr, comp: DBComp, prect: PRect, vp: Viewport, hov, sel: bool, rot: bool) =
  # Draw rectangle, origin, and its text using SDL2 renderer to prect
  # prect is rectangle in pixels
  # hov, sel is whether this is hovering and/or selected
  # rot: true means use default rotated bbox and rotate text
  # rot: false means render as R0, with text unrotated, and box zero'd
  # Generally SDLDirect will use rot=true and false otherwise
  
  rp.drawSolid(prect, comp.fillColor * highlight(hov, sel), comp.penColor)
  rp.drawBorder(prect, comp.penColor, hov, sel)
  rp.drawOrigin(comp, prect, vp.zoom, rot)
  if gAppOpts.enableText:
    rp.drawCompText(comp, prect, vp.zoom, rot)
