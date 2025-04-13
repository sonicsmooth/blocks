import pixie
import sdl2
import std/os
import sdlframes

proc createTextureFromImage(renderer: RendererPtr, image: Image): TexturePtr =
  const 
    rmask = 0x000000ff'u32
    gmask = 0x0000ff00'u32
    bmask = 0x00ff0000'u32
    amask = 0xff000000'u32
  let
    (w,h) = (image.width, image.height)
    d = 32    # depth
    p = 4 * w # pitch
    surface = createRGBSurfaceFrom(addr image.data[0], w, h, d, p,
      rmask, gmask, bmask, amask)
  result = renderer.createTextureFromSurface(surface)
  surface.destroy()

proc pollQuit(): bool =
  var event = defaultEvent
  pollEvent(event) and
    (event.kind == KeyDown or
     event.kind == QuitEvent)

proc checkerBoard(renderer: RendererPtr, w, h: int) =
  let step = 25
  let col = [color(64,64,64,255), color(127,127,127,255)]
  var rect: sdl2.Rect
  for yi in 0 ..< (h div step):
    for xi in 0 ..< (w div step):
      renderer.setDrawColor(col[(xi + yi) mod 2])
      rect = rect(xi * step, yi * step, step, step)
      renderer.fillRect(addr rect)

proc heart(): Image =
  result = newImage(200, 200)
  result.fill(rgba(255, 255, 255, 200)) # clear background

  var path = newPath()
  path.moveTo(20, 60)
  path.ellipticalArcTo(40, 40, 90, false, true, 100, 60)
  path.ellipticalArcTo(40, 40, 90, false, true, 180, 60)
  path.quadraticCurveTo(180, 120, 100, 180)
  path.quadraticCurveTo(20, 120, 20, 60)
  path.closePath()

  result.fillPath(path, "#FC427B")
  result.writeFile("images/heart2.png")


initSDL()
let 
  (w,h) = (800, 600)
  window = createWindow(
    title = "Our own 2D platformer",
    x=SDL_WINDOWPOS_CENTERED, y=SDL_WINDOWPOS_CENTERED,
    w=w, h=h, flags=SDL_WINDOW_SHOWN)
  renderer = window.createRenderer(index = -1,
    flags=Renderer_Accelerated or Renderer_PresentVsync)
  hart = heart()
  heartTexture = renderer.createTextureFromImage(hart)

var
  frect1 = rect(30,30, 100, 100)
  dstrect = rect(55, 55, hart.width, hart.height)
  frect2 = rect(50, 70, 100, 100)

renderer.setDrawBlendMode(BlendMode_Blend)
while true:
  if pollQuit(): break
  renderer.setDrawColor(0,0,0,0)
  renderer.clear()
  renderer.checkerBoard(w, h)
  
  renderer.setDrawColor(0,255,0,127)
  renderer.fillRect(addr frect1)
  renderer.copy(heartTexture, nil, addr dstrect)
  renderer.setDrawColor(0,0,255,127)
  renderer.fillRect(addr frect2)

  renderer.present()
  dstrect.x += 2 

heartTexture.destroy()
