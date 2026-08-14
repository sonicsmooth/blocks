
import std/strformat
import sdl2
import sdl2/image
import sdl2/ttf


type
  SDLException = object of CatchableError


const
  rmask* = 0xff.shl(24).uint32
  gmask* = 0xff.shl(16).uint32
  bmask* = 0xff.shl( 8).uint32
  amask* = 0xff.shl( 0).uint32


template sdlFailIf*(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())

proc initSDL*() =
  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
    "SDL2 initialization failed"

  sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "2")):
    "Linear texture filtering could not be enabled"

  const imgFlags: cint = IMG_INIT_PNG
  sdlFailIf(image.init(imgFlags) != imgFlags):
    "SDL2 Image initialization failed"

  sdlFailIf(ttfInit() == SdlError):
    "SDL2 TTF initialization failed"

proc textureInfo*(texture: TexturePtr): string =
  var pxfmt, rmaskx, gmaskx, bmaskx, amaskx: uint32
  var access, w, h, bpp: cint
  queryTexture(texture, addr pxfmt, addr access, addr w, addr h)
  discard pixelFormatEnumToMasks(pxfmt, bpp, rmaskx, gmaskx, bmaskx, amaskx)
  result &= &"format: {getPixelFormatName(pxfmt)}\n"
  result &= &"rmask : {rmask:08x}\n"
  result &= &"rmaskx: {rmaskx:08x}\n"
  result &= &"gmask : {gmask:08x}\n"
  result &= &"gmaskx: {gmaskx:08x}\n"
  result &= &"bmask : {bmask:08x}\n"
  result &= &"bmaskx: {bmaskx:08x}\n"
  result &= &"amask : {amask:08x}\n"
  result &= &"amaskx: {amaskx:08x}"


when isMainModule:
  import std/tables

  initSDL()
  echo "initSDL()"
  var ver: SDL_VERSION
  getVersion(ver)
  echo "SDL Version: ", ver.major, ".", ver.minor
  echo "SDL Patch: ", ver.patch

  let (w,h) = (640.cint, 480.cint)
  var window = createWindow("Main Module",
                            x = SDL_WINDOWPOS_CENTERED,
                            y = SDL_WINDOWPOS_CENTERED,
                            w = w,
                            h = h,
                            flags = 0)

  # Choose Direct3D 11; default of 9 deletes its
  # textures when screen is resized
  echo "Available renderers"
  var renderIndex: Table[string, int32]
  for i in 0 ..< getNumRenderDrivers():
    var info: RendererInfo
    discard getRenderDriverInfo(i, info)
    echo "  ", i, ": ", info.name
    renderIndex[$info.name] = i

  let renderer = window.createRenderer(renderIndex["direct3d11"],
                 flags = Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)
  sdlFailIf(renderer.isNil): "Renderer could not be created"
  renderer.setDrawBlendMode(BlendMode_Blend)

  var info: RendererInfo
  discard getRendererInfo(renderer, addr info)
  echo "Using renderer: ", info.name

  echo "window.getDisplayMode():"
  var dm: DisplayMode
  discard window.getDisplayMode(dm)
  for key, value in dm.fieldPairs:
    echo "  " & key & ": " & $cast[cint](value)
    if key == "format":
      echo "  formatName: ", $getPixelFormatName(dm.format) #pixelFormatName

  let os = 50.cint
  var r1 = rect(os, os, w-os*3, h-os*3)
  renderer.setDrawColor(255, 128, 64, 128)
  renderer.fillRect(r1)

  var r2 = rect(os*2, os*2, w-os*3, h-os*3)
  renderer.setDrawColor(64, 128, 255, 128)
  renderer.fillRect(r2)
  renderer.present()
  window.show()
  var running = true
  var event: Event
  while running:
    while pollEvent(event):
      case event.kind
      of QuitEvent:
        running = false
      else:
        discard
    delay(16)  

  renderer.destroyRenderer()
  window.destroyWindow()
  sdl2.quit()
  echo "SDL shutdown completed"
