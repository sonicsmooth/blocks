import wnim
import sdl2, sdl2/[image, ttf]
export sdl2, image, ttf

type
  SDLException = object of CatchableError
  wSDLPanel* = ref object of wPanel
    sdlWindow*: WindowPtr
    sdlRenderer*: RendererPtr
  wTestPanel = ref object of wSDLPanel
  wSDLFrame = ref object of wFrame
    mPanel: wTestPanel


template sdlFailIf*(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())


proc initSDL* =
  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
    "SDL2 initialization failed"
  sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "2")):
    "Linear texture filtering could not be enabled"  
  const imgFlags: cint = IMG_INIT_PNG
  sdlFailIf(image.init(imgFlags) != imgFlags):
    "SDL2 Image initialization failed"
  sdlFailIf(ttfInit() == SdlError):
    "SDL2 TTF initialization failed"

wClass(wSDLPanel of wPanel):
  proc init*(self: wSDLPanel, parent: wWindow, style: wStyle) =
    wPanel(self).init(parent, style=style)

    self.sdlWindow = createWindowFrom(cast[pointer] (self.mHwnd))
    sdlFailIf self.sdlWindow.isNil: "Window could not be created"
    let flags = Renderer_Accelerated or Renderer_PresentVsync
    self.sdlRenderer = self.sdlWindow.createRenderer(index = -1, flags=flags)
    sdlFailIf self.sdlRenderer.isNil: "Renderer could not be created"

wClass(wTestPanel of wSDLPanel):
  proc onPaint(self: wTestPanel, event: wEvent) =
    let (w,h) = self.clientSize
    self.sdlRenderer.setDrawColor(r=110, g=132, b=174)
    self.sdlRenderer.clear()
    self.sdlRenderer.setDrawColor(r=255, g=0, b=0)
    var rect: sdl2.Rect = (10, 10, w-20, h-20)
    self.sdlRenderer.fillRect(rect)
    self.sdlRenderer.present()
  proc init*(self: wTestPanel, parent: wWindow) =
    wSDLPanel(self).init(parent)
    self.wEvent_Paint do (event: wEvent): self.onPaint(event)



wClass(wSDLFrame of wFrame):
  proc init*(self: wSDLFrame, size: wSize) =
    echo "wSDLFrame.init 1"
    wFrame(self).init(title="SDL Frame", size=size)
    echo "wSDLFrame.init 2"
    self.mPanel = TestPanel(self)



if isMainModule:
  initSDL()
  var frame = SDLFrame((800,600))
  frame.show()


  let app = App()
  app.mainLoop()