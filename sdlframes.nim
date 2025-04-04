import wnim
import sdl2, sdl2/[image, ttf]


type
  SDLException = object of Exception
  wSDLFrame = ref object of wFrame
    sdlWindow: WindowPtr
    renderer: RendererPtr


template sdlFailIf(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())

type 
  InitResult = tuple
    renderer: RendererPtr
    window: WindowPtr

wClass(wSDLFrame of wFrame):
  proc init*(self: wSDLFrame, size: wSize) =
    wFrame(self).init(title="SDL Frame")
    
    # sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
    #   "SDL2 initialization failed"
    # defer: sdl2.quit()
    # sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "2")):
    #   "Linear texture filtering could not be enabled"  

    # self.sdlWindow = createWindow(
    #   title = "Our own 2D platformer",
    #   x=SDL_WINDOWPOS_CENTERED, y=SDL_WINDOWPOS_CENTERED,
    #   w=1280, h=720, flags=SDL_WINDOW_SHOWN)
    # sdlFailIf self.sdlWindow.isNil: "Window could not be created"
    # defer: self.sdlWindow.destroy()

    # self.renderer = self.sdlWindow.createRenderer(index = -1,
    #   flags=Renderer_Accelerated or Renderer_PresentVsync)
    # sdlFailIf self.renderer.isNil: "Renderer could not be created"
    # defer: self.renderer.destroy()
    # self.renderer.setDrawColor(r=110, g=132, b=174)
    
    # const imgFlags: cint = IMG_INIT_PNG
    # sdlFailIf(image.init(imgFlags) != imgFlags):
    #   "SDL2 Image initialization failed"
    # defer: image.quit()

    # sdlFailIf(ttfInit() == SdlError): "SDL2 TTF initialization failed"
    # defer: ttfQuit()

    self.show()


proc initSDLWindow(window: var WindowPtr, renderer: var RendererPtr) =
  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
    "SDL2 initialization failed"
  sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "2")):
    "Linear texture filtering could not be enabled"  

  window = createWindow(title = "Our own 2D platformer",
    x=SDL_WINDOWPOS_CENTERED, y=SDL_WINDOWPOS_CENTERED,
    w=1280, h=720, flags=SDL_WINDOW_SHOWN)
  sdlFailIf window.isNil:
    "Window could not be created"

  renderer = window.createRenderer(index = -1,
    flags=Renderer_Accelerated or Renderer_PresentVsync)
  sdlFailIf renderer.isNil:
    "Renderer could not be created"
  renderer.setDrawColor(r=110, g=132, b=174)
  
  const imgFlags: cint = IMG_INIT_PNG
  sdlFailIf(image.init(imgFlags) != imgFlags):
    "SDL2 Image initialization failed"

  sdlFailIf(ttfInit() == SdlError):
    "SDL2 TTF initialization failed"
  




if isMainModule:
  var window: WindowPtr
  var renderer: RendererPtr
  initSDLWindow(window, renderer)

  var rect: sdl2.Rect = (50, 50, 500, 500)
  var i: uint8
  while true:
    rect.x = i.cint
    renderer.setDrawColor(r=110, g=132, b=174)
    renderer.clear()
    renderer.setDrawColor(r=i, g=0, b=0)
    renderer.fillRect(rect)
    renderer.present()
    inc i

  # let app = App()
  # discard SDLFrame((800, 600))
  # app.mainLoop()