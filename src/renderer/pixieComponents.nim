import std/[options,
            os,
            tables
]
            
import pixie
import appopts
import colors, colors_pixie
import common
import rects
export Image

const
  gFontScale = 0.45

var
  gTypefaceCache: Table[string, Typeface]
  #gFontName: Option[string]
  gFont: Option[Font] # a cache of 1

proc typeface(name: string): Typeface =
  if name notin gTypefaceCache:
    echo "reading typeface: ", name
    gTypefaceCache[name] = readTypeface(name)
  gTypefaceCache[name]
    
proc tryFont(size: float): Font =
  echo "tryfont ", size
  echo "gfont issome: ", gFont.isSome
  if gFont.isSome:
    echo "returning font"
    return gFont.get
  for p in fontCandidates():
    if fileExists(p):
      result = newFont(typeface(p))
      if not result.isNil:
        echo "Pixie Loaded ", p, " with size ", size
        gFont = some(result)
        return result
      else:
        echo "Could not find ", p
        continue

proc font*(comp: DBComp, zoom: float): Font =
  let wbb = comp.wbbox
  let fsz = min(wbb.w, wbb.h).float
  let scaledSize = (fsz * gFontScale * zoom).round.int.clamp(fontRange)
  result = tryFont(scaledSize)
  if not result.isNil:
    result.size = scaledSize.float
    result.paint.color = comp.penColor

proc drawGradient(image: Image, fillColor: Color) =
  # Implicit conversion using colors_pixie.toPixieColorFloat
  let gradCol1 = fillColor.lighten(0.1)
  let gradCol2 = fillColor.darken(0.1)
  var paint = newPaint(LinearGradientPaint)
  paint.gradientStops = @[colorStop(gradCol1, 0), colorStop(gradCol2, 1)]
  paint.gradientHandlePositions = @[vec2(0, 0), vec2(0, image.height.float)]
  image.fillGradient(paint)

proc drawSolid(image: Image, fillColor: Color) =
  image.fill(fillColor)

proc drawBorder(ctx: Context, penColor: Color, hov, sel: bool, zoom: float) =
  let w = ctx.image.width.float
  let h = ctx.image.height.float

  ctx.lineWidth = 4 * zoom
  ctx.strokeStyle.color = penColor.darken(0.2)
  ctx.strokeRect(pixie.rect(0.0, 0.0, w, h))
  if hov and not sel:
    ctx.strokeRect(pixie.rect(1.0, 1.0, w - 2.0, h - 2.0))
    ctx.strokeRect(pixie.rect(2.0, 2.0, w - 4.0, h - 4.0))
  elif sel:
    ctx.strokeRect(pixie.rect(1.0, 1.0, w - 2.0, h - 2.0))
    ctx.strokeRect(pixie.rect(2.0, 2.0, w - 4.0, h - 4.0))
    ctx.strokeRect(pixie.rect(3.0, 3.0, w - 6.0, h - 6.0))
    ctx.strokeRect(pixie.rect(4.0, 4.0, w - 8.0, h - 8.0))

proc drawOrigin(ctx: Context, opx: PxPoint, penColor: Color, extent: int, zoom: float) = 
  let
    offset = if gAppOpts.oneoffset: 1 else: 0
    midh:   float = opx.x
    left:   float = midh - extent
    right:  float = midh + extent
    midv:   float = opx.y - offset
    top:    float = midv - extent
    bottom: float = midv + extent
  ctx.strokeStyle.color = penColor
  ctx.lineWidth = 1.0 * zoom
  ctx.beginPath()
  ctx.moveTo(vec2(left,  midv   ))
  ctx.lineTo(vec2(right, midv   ))
  ctx.moveTo(vec2(midh,  top    ))
  ctx.lineTo(vec2(midh,  bottom ))
  ctx.stroke()

# TODO: Move to common
proc pxOrigin(comp: DBComp, zoom: float): PxPoint =
  # Return the origin position in pixels
  comp.originToTopLeft(false).toPixelScale(zoom)

proc renderDBCompPixie*(comp: DBComp, texSz: PxSize, hov, sel: bool, zoom: float): Image =
  # Draw rectangle to new surface using pixie and return surface
  # comp is database object
  # PxSize is size of texture to draw to
  # let prect = self.choosePRect(comp, false)
  #  vp = self.editor.viewport
  let image = newImage(texSz.w, texSz.h)
  let ctx = image.newContext()
  image.drawGradient(comp.fillColor)
  ctx.drawBorder(comp.penColor, hov, sel, zoom)
  ctx.drawOrigin(comp.pxOrigin(zoom), comp.penColor, 10, zoom)

  # Text
  let fnt = font(comp, zoom)
  let spans = @[newSpan($comp.id, fnt)]
  image.fillText(typeset(spans, vec2(180, 180)), translate(vec2(10, 10)))



  return image
