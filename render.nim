import std/[tables, math, sugar]
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

proc font(rect: DBRect, zoom: float): FontPtr =
  # Return properly sized font ptr from cache based on rect size
  let px = min(rect.size.w, rect.size.h)
  let scaledSize = (px.float * fontScale * zoom).round.int
  font(scaledSize)

proc renderFilledRect*(rp: RendererPtr, # vp: ViewPort, 
                       rect: PRect, fillColor, penColor: ColorU32) =
  # Draw WRect, return PRect created in the process
  #let prect = rect.toPRect(vp)
  rp.setDrawColor(fillColor.toColor)
  rp.fillRect(addr rect)
  rp.setDrawColor(penColor.toColor)
  rp.drawRect(addr rect)

proc renderOutlineRect*(rp: RendererPtr, #vp: ViewPort,
                        rect: PRect, penColor: ColorU32) =
  #let prect = rect.toPRect(vp)
  rp.setDrawColor(penColor.toColor)
  rp.drawRect(addr rect)

proc renderDBRect*(rp: RendererPtr, vp: ViewPort, rect: DBRect,  sel: bool, zero: bool) =
  # Draw rectangle on SDL2 renderer
  # rp is renderer
  # vp is viewport to convert between pixels and world coords
  # rect is domain object rectangle
  # sel is whether the object should be rendered as selected
  # zero is whether the object should be rendered at upper left corner of target
  #   this should be false when target is screen
  #   and true when target is texture
  
  # When drawn to textureCache
  let prect = 
    if zero: rect.toPRect(vp, rot=false).zero
    else:    rect.toPRect(vp, rot=true)


  # Delegate rectangle to renderWRect after relocating to 0,0
  rp.renderFilledRect(prect, rect.fillColor, rect.penColor)

  # Origin
  # Todo: There is something to be said here about model space
  # todo: to world space to pixel space
  let
    opx: PxPoint = (rect.originXLeft.float * vp.zoom, rect.originYUp.float * vp.zoom)
    extent = 10.0 * vp.zoom
  rp.setDrawColor(Black.toColor)
  rp.drawLine(prect.x + opx.x - extent, prect.y + opx.y, prect.x + opx.x + extent, prect.y + opx.y)
  rp.drawLine(prect.x + opx.x, prect.y + opx.y - extent, prect.x + opx.x, prect.y + opx.y + extent)

  # Text to texture, then texture to renderer
  let 
    (w, h) = (prect.w, prect.h)
    selstr = $rect.id & (if sel: "*" else: "")
    font = rect.font(vp.zoom)
    textSurface = font.renderUtf8Blended(selstr.cstring, Black.toColor)
    (tsw, tsh) = (textSurface.w, textSurface.h)
    dstRect: PRect = (prect.x + (w div 2) - (tsw div 2),
                      prect.y + (h div 2) - (tsh div 2), tsw, tsh)
    textTexture = rp.createTextureFromSurface(textSurface)
  rp.copyEx(textTexture, nil, addr dstRect, -rect.rot.toFloat, nil)
  textTexture.destroy()

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




