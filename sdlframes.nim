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
    rectTextures: seq[TexturePtr]
  wSDLFrame = ref object of wFrame
    mPanel: wTestPanel


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
  proc init*(self: wSDLPanel, parent: wWindow, style: wStyle) =
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
  proc drawRect(self: wTestPanel, rect: Rect) =
    self.sdlRenderer.setDrawColor(rect.color)
    self.sdlRenderer.fillRect(cast[ptr sdl2.Rect](addr rect))

  proc drawRect(self: wTestPanel, rect: Rect, texture: TexturePtr) =
    let dstrect = cast[ptr sdl2.Rect](addr rect)
    self.sdlRenderer.copy(texture, nil, dstrect)

  proc toTexture(self: wTestPanel, rect: Rect): TexturePtr =
    let surface = createRGBSurface(0, rect.w, rect.h, 32, 
      rmask, gmask, bmask, amask)
    surface.fillRect(nil, rect.color.toUint32())
    result = self.sdlRenderer.createTextureFromSurface(surface)
    #echo textureInfo(result)
  
    

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

    for r in self.rects[0..5]:
      self.drawRect(r)

    for i in 6..11:
      self.drawRect(self.rects[i], self.rectTextures[i])

    self.sdlRenderer.present()
    self.refresh()

  proc init*(self: wTestPanel, parent: wWindow) =
    wSDLPanel(self).init(parent)
    self.rects.add(rect( 10,  20, 100, 100, toSDLColor(colRed,     127), (Right, Down)))
    self.rects.add(rect( 30,  40, 100, 100, toSDLColor(colGreen,   127), (Right, Down)))
    self.rects.add(rect( 50,  60, 100, 100, toSDLColor(colBlue,    127), (Right, Down)))
    self.rects.add(rect( 70,  80, 100, 100, toSDLColor(colCyan,    127), (Right, Down)))
    self.rects.add(rect( 90, 100, 100, 100, toSDLColor(colMagenta, 127), (Right, Down)))
    self.rects.add(rect(110, 120, 100, 100, toSDLColor(colYellow,  127), (Right, Down)))

    self.rects.add(rect(110, 120, 100, 100, toSDLColor(colTomato,          200), (Left, Down)))
    self.rects.add(rect(130, 140, 100, 100, toSDLColor(colLawnGreen,       200), (Left, Down)))
    self.rects.add(rect(150, 160, 100, 100, toSDLColor(colLightCoral,      200), (Left, Down)))
    self.rects.add(rect(170, 180, 100, 100, toSDLColor(colRoyalBlue,       200), (Left, Down)))
    self.rects.add(rect(190, 200, 100, 100, toSDLColor(colMaroon,          200), (Left, Down)))
    self.rects.add(rect(210, 220, 100, 100, toSDLColor(colMediumTurquoise, 200), (Left, Down)))

    for r in self.rects:
      self.rectTextures.add(self.toTexture(r))

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