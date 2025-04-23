import wnim
import sdl2, sdl2/[image, ttf]
import utils
export sdl2, image, ttf


type
  XDirection = enum Right, Left
  YDirection = enum Up, Down
  Direction = tuple[x: XDirection, y: YDirection]
  Rect = tuple
    x, y: cint
    w, h: cint
    color: Color
    dir: Direction
  wSDLPanel* = ref object of wPanel
    sdlWindow*: WindowPtr
    sdlRenderer*: RendererPtr
    pixelFormat: uint32
    pixelFormatName: string
  wTestPanel = ref object of wSDLPanel
    rects: seq[Rect]
  wSDLFrame = ref object of wFrame
    mPanel: wTestPanel

when false: # ARGB
  const
    ASH = 24
    RSH = 16
    GSH =  8
    BSH =  0
else: # RGBA
  const
    RSH = 24
    GSH = 16
    BSH =  8
    ASH =  0
const
  rmask = 0xff.shl(RSH).uint32
  gmask = 0xff.shl(GSH).uint32
  bmask = 0xff.shl(BSH).uint32
  amask = 0xff.shl(ASH).uint32


proc rect(x,y,w,h: cint, color: Color, dir: Direction): Rect =
  result.x = x
  result.y = y
  result.w = w
  result.h = h
  result.color = color
  result.dir = dir

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
    self.pixelFormat = dm.format
    self.pixelFormatName = $getPixelFormatName(dm.format)
    echo "Window DisplayMode():"
    for key, value in fieldPairs(dm):
      echo key & ": " & $cast[cint](value)
    echo "formatName: ", self.pixelFormatName



wClass(wTestPanel of wSDLPanel):
  proc drawRect(self: wTestPanel, rect: Rect) =
    self.sdlRenderer.setDrawColor(rect.color)
    self.sdlRenderer.fillRect(cast[ptr sdl2.Rect](addr rect))

  proc textRect(self: wTestPanel, rect: Rect) = 
    let surface = createRGBSurface(0, rect.w, rect.h, 32, 
      rmask, gmask, bmask, amask)
    discard surface.setSurfaceBlendMode(BlendMode_Blend)
    surface.fillRect(nil, rect.color.toRGBA())
    let texture = self.sdlRenderer.createTextureFromSurface(surface)
    #texture.setTextureBlendMode(BlendMode_Blend)
    let prect = cast[ptr sdl2.Rect](addr rect)
    self.sdlRenderer.copy(texture, nil, prect)
    

  proc updateRect(self: wTestPanel, rect: ptr Rect) =
    if rect.dir.x == Right and rect.x >= self.size.width - rect.w:
      rect.dir.x = Left
    if rect.dir.x == Left and rect.x <= 0:
      rect.dir.x = Right
    if rect.dir.y == Down and rect.y >= self.size.height - rect.h:
      rect.dir.y = Up
    if rect.dir.y == Up and rect.y <= 0:
      rect.dir.y = Down
    if rect.dir.x == Right: rect.x += 2
    else: rect.x -= 3
    if rect.dir.y == Down: rect.y += 3
    else: rect.y -= 2

  proc onPaint(self: wTestPanel, event: wEvent) =
    self.sdlRenderer.setDrawColor(r=110, g=132, b=174)
    self.sdlRenderer.clear()
    for r in self.rects:
      self.updateRect(addr r)
    for r in self.rects[0..2]:
      self.drawRect(r)
    for r in self.rects[3..5]:
      self.textRect(r)
    self.sdlRenderer.present()
    self.refresh()

  proc init*(self: wTestPanel, parent: wWindow) =
    wSDLPanel(self).init(parent)
    self.rects.add(rect( 10,  20, 100, 100, color(255,0,0,127), (Right, Down)))
    self.rects.add(rect( 30,  40, 100, 100, color(0,255,0,127), (Right, Down)))
    self.rects.add(rect( 50,  60, 100, 100, color(0,0,255,127), (Right, Down)))
    self.rects.add(rect( 70,  80, 100, 100, color(0,255,255,17), (Right, Down)))
    self.rects.add(rect( 90, 100, 100, 100, color(255,0,255,127), (Right, Down)))
    self.rects.add(rect(110, 120, 100, 100, color(255,255,0,127), (Right, Down)))
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