
import pixie
import colors, colors_pixie
export Rect

proc newFont(typeface: Typeface, size: float32, color: pixie.Color): Font =
  result = newFont(typeface)
  result.size = size
  result.paint.color = color

proc heart*(w,h: int): Image =
  result = newImage(w, h)
  result.fill(rgba(255, 255, 255, 10)) # clear background

  var path = newPath()
  path.moveTo(20, 60)
  path.ellipticalArcTo(40, 40, 90, false, true, 100, 60)
  path.ellipticalArcTo(40, 40, 90, false, true, 180, 60)
  path.quadraticCurveTo(180, 120, 100, 180)
  path.quadraticCurveTo(20, 120, 20, 60)
  path.closePath()
  let scale = w.float / 180.0
  path.transform(scale(vec2(scale, scale)))
  result.fillPath(path, "#7B42FC")
  #result.fillPath(path, "#ffffff")

proc junkTxt*(w,h: int): Image = 
  let typeface = readTypeface("fonts/Ubuntu-Regular_1.ttf")
  let spans = @[
    newSpan("verb [with object] ",
      newFont(typeface, 12, color(0.78125, 0.78125, 0.78125, 1))),
    newSpan("strallow\n", newFont(typeface, 36, color(0, 0, 0, 1))),
    newSpan("\nstral·low\n", newFont(typeface, 13, color(0.953125, 0.5, 0, 1))),
    newSpan("\n1. free (something) from restrictive restrictions \"the regulations are intended to strallow changes in public policy\" ",
        newFont(typeface, 14, color(0.3125, 0.3125, 0.3125, 1)))]
  result = newImage(w, h)
  result.fillText(typeset(spans, vec2(180, 180)), translate(vec2(10, 10)))

proc checkers*(w, h: int): Image =
  result = newImage(w, h)
  let ctx = result.newContext()
  let sz = 20.0
  let wh = vec2(sz, sz)
  for y in 0..<10:
    if y mod 2 == 0:
      for x in 0..<10:
        if x mod 2 == 0:
          var pos = vec2(x.float * sz, y.float * sz)
          ctx.fillStyle = rgba(0, 255, 0, 255)
          ctx.fillRect(rect(pos, wh))
          pos = vec2((x.float+1) * sz, y.float * sz)
          ctx.fillStyle = rgba(255, 0, 0, 255)
          ctx.fillRect(rect(pos, wh))
    else:
      for x in 0..<10:
        if x mod 2 == 1:
          var pos = vec2(x.float * sz, y.float * sz)
          ctx.fillStyle = rgba(0, 255, 0, 255)
          ctx.fillRect(rect(pos, wh))
          pos = vec2((x.float-1) * sz, y.float * sz)
          ctx.fillStyle = rgba(0, 0, 255, 255)
          ctx.fillRect(rect(pos, wh))

proc basicBox*(w, h: int, penColor, fillColor: colors.ColorRGBA): Image =
  result = newImage(w, h)
  let ctx = result.newContext()
  ctx.fillStyle = fillColor.toPixieColorFloat()
  ctx.strokeStyle = penColor.toPixieColorFloat()
  ctx.lineWidth = 2.0
  ctx.fillRect(rect(0.0, 0.0, w.float, h.float))
  ctx.strokeRect(rect(0.0, 0.0, w.float, h.float))

proc gradientBox*(w, h: int, penColor, fillColor1, fillColor2: colors.ColorRGBA): Image =
  result = newImage(w, h)
  let 
    col1 = fillColor1.toPixieColorFloat()
    col2 = fillColor2.toPixieColorFloat()
  var paint = newPaint(LinearGradientPaint)
  paint.gradientStops = @[colorStop(col1, 0), colorStop(col2, 1)]
  paint.gradientHandlePositions = @[vec2(0, 0), vec2(0, h.float)]
  result.fillGradient(paint)

  let ctx = result.newContext()
  ctx.strokeStyle = penColor.toPixieColorFloat()
  ctx.lineWidth = 4
  ctx.strokeRect(rect(0.0, 0.0, w.float, h.float))

when isMainModule:
  let image = checkers(200, 200)
  image.writeFile("square.png")
