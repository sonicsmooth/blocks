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

var cnt = 0
proc renderDBRect*(rp: RendererPtr, vp: ViewPort, rect: DBRect,  sel: bool) =
  # Draw rectangle on SDL2 renderer
  echo "renderdbrect"
  let prect = rect.toPRect(vp, rot=false)
  let pz = prect.zero

  # Delegate rectangle to renderWRect after relocating to 0,0
  rp.renderFilledRect(pz, rect.fillColor, rect.penColor)

  # Origin
  # Todo: There is something to be said here about model space
  # todo: to world space to pixel space
  let
    opx = (rect.origin.x.float * vp.zoom, (-rect.origin.y + rect.h).float * vp.zoom).toPxPoint
    extent = 10.0 * vp.zoom
  rp.setDrawColor(Black.toColor)
  rp.drawLine(opx.x - extent, opx.y, opx.x + extent, opx.y)
  rp.drawLine(opx.x, opx.y - extent, opx.x, opx.y + extent)
  rp.drawLine(0, 0, pz.w div 2, pz.h div 2)

  # Text to texture, then texture to renderer
  let 
    (w, h) = (prect.w, prect.h)
    selstr = $rect.id & "_" & $cnt & (if sel: "*" else: "")
    font = rect.font(vp.zoom)
    textSurface = font.renderUtf8Blended(selstr.cstring, Black.toColor)
    (tsw, tsh) = (textSurface.w, textSurface.h)
    dstRect: PRect = ((w div 2) - (tsw div 2),
                      (h div 2) - (tsh div 2), tsw, tsh)
    textTexture = rp.createTextureFromSurface(textSurface)
  cnt.inc
  rp.copy(textTexture, nil, addr dstRect)
  textTexture.destroy()

proc renderDBRect*(surface: SurfacePtr, vp: ViewPort, rect: DBRect, sel: bool) =
  let rp = createSoftwareRenderer(surface)
  rp.renderDBRect(vp, rect, sel)

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




