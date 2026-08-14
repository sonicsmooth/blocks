import std/[options,
            os,
            tables
]
            
import pixie
import appopts
import colors
import colors_pixie
import common
import rects
export Image

const
  gFontScale = 0.45

var
  gTypefaceCache: Table[string, Typeface]
  gFont: Option[Font] # a cache of 1

proc typeface(name: string): Typeface =
  if name notin gTypefaceCache:
    gTypefaceCache[name] = readTypeface(name)
  result = gTypefaceCache[name]
    
proc tryFont(size: float): Font =
  if gFont.isSome:
    return gFont.get
  for p in fontCandidates():
    if fileExists(p):
      result = newFont(typeface(p))
      if not result.isNil:
        gFont = some(result)
        return result
      else:
        echo "Could not find ", p
        continue

proc font*(comp: DBComp, zoom: float): Font =
  let 
    wbb = comp.wbbox
    fsz = min(wbb.w, wbb.h).float
    scaledSize = (fsz * gFontScale * zoom).round.int.clamp(fontRange)
  result = tryFont(scaledSize)
  if not result.isNil:
    result.size = scaledSize.float
    result.paint.color = comp.penColor

proc clearTypefaceCache*() = 
  gTypefaceCache.clear()
  gFont = none[Font]()

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
  ctx.lineWidth = 1 * zoom
  ctx.strokeStyle.color = penColor
  if not hov and not sel:
    ctx.strokeRect(pixie.rect(0.0, 0.0, w,       h      ))
  elif hov and not sel:
    ctx.strokeRect(pixie.rect(0.0, 0.0, w,       h      ))
    ctx.strokeRect(pixie.rect(1.0, 1.0, w - 2.0, h - 2.0))
  elif sel:
    ctx.strokeRect(pixie.rect(0.0, 0.0, w,       h      ))
    ctx.strokeRect(pixie.rect(1.0, 1.0, w - 2.0, h - 2.0))
    ctx.strokeRect(pixie.rect(2.0, 2.0, w - 4.0, h - 4.0))

proc drawCompText(image: Image, comp: DBComp, zoom: float) =
  let
    fnt = font(comp, zoom) # includes modified comp.penColor 
    spans = @[newSpan($comp.id, fnt)]
    (w,h) = (image.width.float, image.height.float)
    arrangement = typeset(spans, vec2(w, h), CenterAlign, MiddleAlign)
  image.fillText(arrangement)

proc drawOrigin(ctx: Context, opx: PxPoint, penColor: Color, zoom: float) = 
  let
    extent = 10 * zoom
    offset = if gAppOpts.oneoffset: 1 else: 0
    midh:   float = opx.x.float
    left:   float = midh - extent
    right:  float = midh + extent
    midv:   float = opx.y.float - offset
    top:    float = midv - extent
    bottom: float = midv + extent
  ctx.fillStyle = color(penColor.r, penColor.g, penColor.b, 1.0).darken(0.2)
  ctx.fillRect(left, midv, right-left, 1) # Horizontal
  ctx.fillRect(midh, top,  1, bottom-top) # Vertical

proc renderDBCompPixie*(comp: DBComp, texSz: PxSize, hov, sel: bool, zoom: float): Image =
  # Draw rectangle to new image using pixie and return image
  # comp is database object
  # PxSize is size of texture to draw to
  let image = newImage(texSz.w, texSz.h)
  let ctx = image.newContext()
  if gAppOpts.blockFill == Solid:
    image.drawSolid(comp.fillColor)
  elif gAppOPts.blockFill == Gradient:
    image.drawGradient(comp.fillColor)
  ctx.drawBorder(comp.penColor, hov, sel, zoom)
  ctx.drawOrigin(comp.pxOrigin(zoom), comp.penColor, zoom)
  if gAppOpts.enableText:
    image.drawCompText(comp, zoom)



  return image
