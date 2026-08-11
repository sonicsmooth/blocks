
import sdl2
import pixie except Color, ColorRGBA
import common
import colors, colors_pixie
import rects

proc renderDBCompPixie*(comp: DBComp, texSz: PxSize, hov, sel: bool): SurfacePtr =
  # Draw rectangle to new surface using pixie and return surface
  # comp is database object
  # prect is target rectangle with same aspect ratio as comp
  # let prect = self.choosePRect(comp, false)
  #  vp = self.editor.viewport
  var fillColor = comp.fillColor.toPixieColorFloat
  fillColor.a = 200.0 / 255.0
  var fc1 = fillColor.lighten(0.1)
  var fc2 = fillColor.darken(0.1)
  var pc = fillColor.darken(0.2)
  #pc.a = 1.0
  let image = newImage(texSz.w, texSz.h)
  var paint = newPaint(LinearGradientPaint)
  paint.gradientStops = @[colorStop(fc1, 0), colorStop(fc2, 1)]
  paint.gradientHandlePositions = @[vec2(0, 0), vec2(0, texSz.h.float)]
  image.fillGradient(paint)
  let ctx = image.newContext()
  ctx.strokeStyle.color = pc
  ctx.lineWidth = 40
  # for i in 0..20:
  #   let y = i*3
  #   ctx.beginPath()
  #   ctx.moveTo(vec2(10, y + 5.0))
  #   ctx.lineTo(vec2(60, y + 5.0))
  #   ctx.lineWidth = 1.0
  #   ctx.stroke()

  ctx.lineWidth = 4
  ctx.strokeRect(pixie.rect(0.0, 0.0, texSz.w.float, texSz.h.float))
  if hov and not sel:
    ctx.strokeRect(pixie.rect(1.0, 1.0, texSz.w.float-2.0, texSz.h.float-2.0))
    ctx.strokeRect(pixie.rect(2.0, 2.0, texSz.w.float-4.0, texSz.h.float-4.0))
  elif sel:
    ctx.strokeRect(pixie.rect(1.0, 1.0, texSz.w.float-2.0, texSz.h.float-2.0))
    ctx.strokeRect(pixie.rect(2.0, 2.0, texSz.w.float-4.0, texSz.h.float-4.0))
    ctx.strokeRect(pixie.rect(3.0, 3.0, texSz.w.float-6.0, texSz.h.float-6.0))
    ctx.strokeRect(pixie.rect(4.0, 4.0, texSz.w.float-8.0, texSz.h.float-8.0))

  # Swizzle the mask order because of endianness
  result = createRGBSurfaceFrom(image.data[0].addr, texSz.w, texSz.h, 
                                32, texSz.w * 4, amask, bmask, gmask, rmask)
  if result.isNil:
    echo "Create surface failed"
    echo getError()
