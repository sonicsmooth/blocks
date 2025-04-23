import std/[strformat, random]
import wnim
import sdl2, sdl2/[image, ttf]
import utils
export sdl2, image, ttf


type
  XDirection = enum Right, Left
  YDirection = enum Up, Down
  Direction = tuple[x: XDirection, y: YDirection]
  wSDLPanel* = ref object of wPanel
    sdlWindow*: WindowPtr
    sdlRenderer*: RendererPtr
    pixelFormatName: string
  wTestPanel = ref object of wSDLPanel
    rrect, grect, brect: Rect
    rdir, gdir, bdir: Direction
  wSDLFrame = ref object of wFrame
    mPanel: wTestPanel

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

wClass(wSDLPanel of wPanel):
  proc init*(self: wSDLPanel, parent: wWindow) =
    wPanel(self).init(parent)

    self.sdlWindow = createWindowFrom(cast[pointer] (self.mHwnd))
    sdlFailIf self.sdlWindow.isNil: "Window could not be created"
    
    let flags = Renderer_Accelerated or Renderer_PresentVsync
    self.sdlRenderer = self.sdlWindow.createRenderer(index = -1, flags=flags)
    sdlFailIf self.sdlRenderer.isNil: "Renderer could not be created"
    self.sdlRenderer.setDrawBlendMode(BlendMode_Blend)

    var dm: DisplayMode 
    discard getDisplayMode(self.sdlWindow, dm)
    self.pixelFormatName = $getPixelFormatName(dm.format)
    echo "Window DisplayMode():"
    for key, value in fieldPairs(dm):
      echo key & ": " & $cast[cint](value)
    echo "formatName: ", self.pixelFormatName



wClass(wTestPanel of wSDLPanel):
  proc drawRect(self: wTestPanel, rect: Rect, color: Color) =
    self.sdlRenderer.setDrawColor(color)
    self.sdlRenderer.fillRect(addr rect)

  proc updateRect(self: wTestPanel, rect: var Rect, dir: var Direction) =
    if dir.x == Right and rect.x >= self.size.width - rect.w:
      dir.x = Left
    if dir.x == Left and rect.x <= 0:
      dir.x = Right
    if dir.y == Down and rect.y >= self.size.height - rect.h:
      dir.y = Up
    if dir.y == Up and rect.y <= 0:
      dir.y = Down
    if dir.x == Right: rect.x += 2
    else: rect.x -= 3
    if dir.y == Down: rect.y += 3
    else: rect.y -= 2

  proc onPaint(self: wTestPanel, event: wEvent) =
    self.sdlRenderer.setDrawColor(r=110, g=132, b=174)
    self.sdlRenderer.clear()
    self.updateRect(self.rrect, self.rdir)
    self.updateRect(self.grect, self.gdir)
    self.updateRect(self.brect, self.bdir)
    self.drawRect(self.rrect, color(255, 0, 0, 127))
    self.drawRect(self.grect, color(0, 255, 0, 127))
    self.drawRect(self.brect, color(0, 0, 255, 127))
    self.sdlRenderer.present()
    self.refresh()

  proc init*(self: wTestPanel, parent: wWindow) =
    wSDLPanel(self).init(parent)
    self.rrect = rect(10, 20, 100, 100)
    self.grect = rect(30, 40, 100, 100)
    self.brect = rect(50, 60, 100, 100)

    self.wEvent_Paint do (event: wEvent): self.onPaint(event)



wClass(wSDLFrame of wFrame):
  proc init*(self: wSDLFrame, size: wSize) =
    wFrame(self).init(title="SDL Frame", size=size)
    self.mPanel = TestPanel(self)


if isMainModule:
  initSDL()
  var frame = SDLFrame((800,600))
  frame.show()

  let app = App()
  app.mainLoop()