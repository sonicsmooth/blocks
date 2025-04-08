import wnim
import sdl2, sdl2/[image, ttf]


type
  SDLException = object of Exception
  wSDLFrame = ref object of wFrame
    sdlWindow: WindowPtr
    sdlRenderer: RendererPtr


template sdlFailIf(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())


proc initSDL =
  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
    "SDL2 initialization failed"
  sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "2")):
    "Linear texture filtering could not be enabled"  
  const imgFlags: cint = IMG_INIT_PNG
  sdlFailIf(image.init(imgFlags) != imgFlags):
    "SDL2 Image initialization failed"
  sdlFailIf(ttfInit() == SdlError):
    "SDL2 TTF initialization failed"


wClass(wSDLFrame of wFrame):
  proc onResize(self: wSDLFrame, event: wEvent) =
    let (w,h) = event.size
    self.sdlRenderer.setDrawColor(r=110, g=132, b=174)
    self.sdlRenderer.clear()
    self.sdlRenderer.setDrawColor(r=255, g=0, b=0)
    var rect: sdl2.Rect = (10, 10, w-20, h-20)
    self.sdlRenderer.fillRect(rect)
    self.sdlRenderer.present()

  proc init*(self: wSDLFrame, size: wSize) =
    wFrame(self).init(title="SDL Frame")
    
    self.sdlWindow = createWindowFrom(cast[pointer] (self.mHwnd))
    sdlFailIf self.sdlWindow.isNil: "Window could not be created"

    let flags = Renderer_Accelerated or Renderer_PresentVsync
    self.sdlRenderer = self.sdlWindow.createRenderer(index = -1, flags=flags)
    sdlFailIf self.sdlRenderer.isNil: "Renderer could not be created"

    self.wEvent_Size do (event: wEvent): self.onResize(event)



if isMainModule:
  initSDL()
  var frame = SDLFrame((800,600))
  frame.show()


  let app = App()
  app.mainLoop()