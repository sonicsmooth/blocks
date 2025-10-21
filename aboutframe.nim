import wnim, winim
import pixie


type
  wAboutFrame* = ref object of wFrame
  #  mImage*: Image


proc newFont(typeface: Typeface, size: float32, color: pixie.Color): Font =
  result = newFont(typeface)
  result.size = size
  result.paint.color = color

proc heart(w,h: int): Image =
  result = newImage(w, h)
  result.fill(rgba(255, 255, 255, 200)) # clear background

  var path = newPath()
  path.moveTo(20, 60)
  path.ellipticalArcTo(40, 40, 90, false, true, 100, 60)
  path.ellipticalArcTo(40, 40, 90, false, true, 180, 60)
  path.quadraticCurveTo(180, 120, 100, 180)
  path.quadraticCurveTo(20, 120, 20, 60)
  path.closePath()
  result.fillPath(path, "#7B42FC")

proc junkTxt(w,h: int): Image = 
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

var cnt: int
wClass(wAboutFrame of wFrame):
  proc onPaint(self: wAboutFrame, event: wEvent) =
    var
      pdc = PaintDC(self)
      bmpDc: HDC
      hbmp: HBITMAP
    let
      rect = pdc.paintRect
      w = rect.width
      h = rect.height
   
    if cnt mod 3 == 2:
      let rect = windef.RECT(left: 0, top: 0, right: w-1, bottom: h-1)
      let hbr = CreateSolidBrush(RGB(255,0,0))
      hbmp = CreateBitmap(w, h, 1, 32, nil)
      bmpDc = CreateCompatibleDC(pdc.mHdc)
      SelectObject(bmpDc, hbmp)
      FillRect(bmpDc, rect.addr, hbr)
      BitBlt(pdc.mHdc, 0, 0, w, h, bmpDc, 0, 0, SRCCOPY)
      DeleteObject(hbr)
      DeleteObject(hbmp)
      DeleteObject(bmpDc)
    else:
      let image = 
        if cnt mod 3 == 1: heart(w, h)
        else: junkTxt(w, h)
      hbmp = CreateBitmap(w,h,1,32,image.data[0].addr)
      bmpDc = CreateCompatibleDC(0.HDC)
      SelectObject(bmpDc, hbmp)
      BitBlt(pdc.mHdc, 0, 0, w, h, bmpDc,0, 0, SRCCOPY)
      DeleteObject(hbmp)
      DeleteObject(bmpDc)
    
    cnt.inc

  proc init*(self: wAboutFrame, owner: wWindow) =
    wFrame(self).init(owner,
                      title="About",
                      pos=(400, 400),
                      size=(640, 480),
                      style=wDefaultFrameStyle)
    self.wEvent_Paint do(event: wEvent): self.onPaint(event)


when isMainModule:
  let
    app = App()
    f = AboutFrame(nil)
  f.show()
  app.mainLoop()