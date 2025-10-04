import wnim
import sdl2, sdl2/[image, ttf]
import utils, colors
export sdl2, image, ttf, colors


type
  XDirection = enum Right, Left
  YDirection = enum Up, Down
  Direction = tuple[x: XDirection, y: YDirection]
  TestRect = tuple
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
    rects: seq[TestRect]
    rectTextures: seq[TexturePtr]
  wSDLFrame = ref object of wFrame
    mPanel: wTestPanel

proc rect(x,y,w,h: cint, color: Color, dir: Direction): TestRect =
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
  proc init*(self: wSDLPanel, parent: wWindow, style: wStyle=0) =
    echo "wSDLPanel.init()"
    wPanel(self).init(parent, style=style)

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
  proc drawRect(self: wTestPanel, rect: TestRect) =
    self.sdlRenderer.setDrawColor(rect.color)
    self.sdlRenderer.fillRect(cast[ptr sdl2.Rect](addr rect))
  proc drawRect(self: wTestPanel, rect: TestRect, texture: TexturePtr) =
    let dstrect = cast[ptr sdl2.Rect](addr rect)
    self.sdlRenderer.copy(texture, nil, dstrect)
  proc toTexture(self: wTestPanel, rect: TestRect): TexturePtr =
    let surface = createRGBSurface(0, rect.w, rect.h, 32, 
      rmask, gmask, bmask, amask)
    surface.fillRect(nil, rect.color.toColorU32.uint32)
    result = self.sdlRenderer.createTextureFromSurface(surface)
  proc updateRect(self: wTestPanel, rect: ptr TestRect) =
    let step = 2
    if rect.dir.x == Right and rect.x >= self.size.width - rect.w:
      rect.dir.x = Left
    if rect.dir.x == Left and rect.x <= 0:
      rect.dir.x = Right
    if rect.dir.y == Down and rect.y >= self.size.height - rect.h:
      rect.dir.y = Up
    if rect.dir.y == Up and rect.y <= 0:
      rect.dir.y = Down
    if rect.dir.x == Right: rect.x += step
    else: rect.x -= step
    if rect.dir.y == Down: rect.y += step
    else: rect.y -= step

  proc onPaint(self: wTestPanel, event: wEvent) =
    self.sdlRenderer.setDrawColor(r=110, g=132, b=174)
    self.sdlRenderer.clear()

    for r in self.rects:
      self.updateRect(addr r)

    for r in self.rects[0..5]:
      self.drawRect(r)

    for i in 6..11:
      self.drawRect(self.rects[i], self.rectTextures[i])

    self.sdlRenderer.present()
    self.refresh()

  proc init*(self: wTestPanel, parent: wWindow) =
    echo "wTestPanel.init()"
    wSDLPanel(self).init(parent) #, style=wBorderSimple)
    self.rects.add(rect( 10,  20, 100, 100, toColor(Red,     127), (Right, Down)))
    self.rects.add(rect( 30,  40, 100, 100, toColor(Green,   127), (Right, Down)))
    self.rects.add(rect( 50,  60, 100, 100, toColor(Blue,    127), (Right, Down)))
    self.rects.add(rect( 70,  80, 100, 100, toColor(Cyan,    127), (Right, Down)))
    self.rects.add(rect( 90, 100, 100, 100, toColor(Magenta, 127), (Right, Down)))
    self.rects.add(rect(110, 120, 100, 100, toColor(Yellow,  127), (Right, Down)))

    self.rects.add(rect(110, 120, 100, 100, toColor(Tomato,          200), (Left, Down)))
    self.rects.add(rect(130, 140, 100, 100, toColor(LawnGreen,       200), (Left, Down)))
    self.rects.add(rect(150, 160, 100, 100, toColor(LightCoral,      200), (Left, Down)))
    self.rects.add(rect(170, 180, 100, 100, toColor(RoyalBlue,       200), (Left, Down)))
    self.rects.add(rect(190, 200, 100, 100, toColor(Maroon,          200), (Left, Down)))
    self.rects.add(rect(210, 220, 100, 100, toColor(MediumTurquoise, 200), (Left, Down)))

    for r in self.rects:
      self.rectTextures.add(self.toTexture(r))

    self.wEvent_Paint do (event: wEvent): self.onPaint(event)

wClass(wSDLFrame of wFrame):
  proc init*(self: wSDLFrame, size: wSize) =
    echo "wSDLFrame.init()"
    wFrame(self).init(title="SDL Frame", size=size)
    self.mPanel = TestPanel(self)


if isMainModule:
  initSDL()
  var frame = SDLFrame((800,600))
  frame.show()

  let app = App()
  app.mainLoop()