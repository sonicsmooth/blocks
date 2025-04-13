import strformat, strutils, times, math
import sdl2
import sdl2/[image, ttf]


type
  SDLException = object of Exception
  Input {.pure.} = enum none, left, right, jump, restart, quit
  Vector2D = tuple[x, y: cint]
  Vector2Df = tuple[x, y: float]
  Time = ref object
    begin, finish, best: int
  Player = ref object
    texture: TexturePtr
    pos: Vector2Df
    vel: Vector2Df
    time: Time
  Map = ref object
    texture: TexturePtr
    width, height: int
    tiles: seq[uint8]
  Collision {.pure.} = enum x, y, corner
  Game = ref object
    inputs: array[Input, bool]
    renderer: RendererPtr
    font: FontPtr
    player: Player
    map: Map
    camera: Vector2Df
  CacheLine = object
    texture: TexturePtr
    w, h: cint
  TextCache = ref object
    text: string
    cache: array[2, CacheLine]

const
  tilesPerRow = 16
  tileSize: Vector2D = (64, 64)
  playerSize: Vector2D = (64, 64)
  windowSize: Vector2D = (1280, 720)
  air = 0
  start = 78
  finish = 110

var
  startTime = epochTime()
  lastTick = 0

template sdlFailIf(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())
proc `+`[T:Vector2D|Vector2Df](v1, v2: T): T =
  result.x = v1.x + v2.x
  result.y = v1.y + v2.y
proc `-`[T:Vector2D|Vector2Df](v1, v2: T): T =
  result.x = v1.x - v2.x
  result.y = v1.y - v2.y
proc `*`[T:Vector2D|Vector2Df](v1: T, m:cint|int|float): T =
  when v1 is Vector2D:
    when m is cint:
      (v1.x * m, 
       v1.y * m)
    elif m is int:
      ((v1.x * m.cint).cint, 
       (v1.y * m.cint).cint)
    elif m is float:
      ((v1.x.float * m).round.cint,
       (v1.y.float * m).round.cint)
  else:
    when m is cint:
      ((v1.x * m.float).round.float,
       (v1.y * m.float).round.float)
    elif m is int:
      ((v1.x * m.float).round.float,
       (v1.y * m.float).round.float)
    elif m is float:
      (v1.x * m,
       v1.y * m)
proc `/`[T:Vector2D|Vector2Df](v1: T, m:cint|int|float): T =
  when v1 is Vector2D:
    when m is cint:
      (v1.x / m, 
       v1.y / m)
    elif m is int:
      ((v1.x / m.cint).cint, 
       (v1.y / m.cint).cint)
    elif m is float:
      ((v1.x.float / m).round.cint,
       (v1.y.float / m).round.cint)
  else:
    when m is cint:
      ((v1.x / m.float).round.float,
       (v1.y / m.float).round.float)
    elif m is int:
      ((v1.x / m.float).round.float,
       (v1.y / m.float).round.float)
    elif m is float:
      (v1.x / m,
       v1.y / m)
proc toVector2Df(v1: Vector2D|Vector2Df): Vector2Df =
  (v1.x.float, v1.y.float)
proc toVector2D(v1:Vector2D|Vector2Df): Vector2D =
  when v1 is Vector2D:
    v1
  else:
    (v1.x.round.cint, v1.y.round.cint)
proc vector2D(x,y: cint):   Vector2D =  (x, y)
proc vector2D(x,y: float):  Vector2D =  (x.round.cint, y.round.cint)
proc vector2Df(x,y: cint):  Vector2Df = (x.float, y.float)
proc vector2Df(x,y: float): Vector2Df = (x, y)
proc diag[T:Vector2D|Vector2Df](v1: T): float =
  sqrt(v1.x.float^2 + v1.y.float^2)
proc newTextCache: TextCache = new result

proc renderText(renderer: RendererPtr, font: FontPtr, text: string,
                x, y, outline: cint, color: Color): CacheLine =
  font.setFontOutline(outline)
  let surface = font.renderUtf8Blended(text.cstring, color)
  sdlFailIf surface.isNil: "Could not render text surface"
  discard surface.setSurfaceAlphaMod(color.a)
  result.w = surface.w
  result.h = surface.h
  result.texture = renderer.createTextureFromSurface(surface)
  sdlFailIf result.texture.isNil:
    "Could not create texture from rendered text"
  surface.freeSurface()

proc renderText(game: Game, text: string, x, y: cint,
                color: Color, tc: TextCache) =
  let passes = [(color: color(0,0,0,64), outline: 2.cint),
                (color: color, outline: 0.cint)]
  if text != tc.text:
    for i in 0 .. 1:
      tc.cache[i].texture.destroy()
      tc.cache[i] = game.renderer.renderText(
        game.font, text, x, y, passes[i].outline, passes[i].color)
      tc.text = text
  for i in 0 .. 1:
    var source = rect(0, 0, tc.cache[i].w, tc.cache[i].h)
    var dest = rect(x - passes[i].outline, y - passes[i].outline,
                    tc.cache[i].w, tc.cache[i].h)
    game.renderer.copyEx(tc.cache[i].texture, source, dest,
                         angle = 0.0, center = nil)

template renderTextCached(game: Game, text: string, x, y: cint, color: Color) =
  block:
    var tc {.global.} = newTextCache()
    game.renderText(text, x, y, color, tc)

proc renderTee(renderer: RendererPtr, texture: TexturePtr, pos: Vector2Df) =
  let x = pos.x.cint
  let y = pos.y.cint
  var bodyParts: array[8, tuple[src, dst: Rect, flip: cint]] = [
    (rect(192, 64, 64, 32), rect(x - 60, y,      96, 48), SDL_FLIP_NONE),
    (rect( 96,  0, 96, 96), rect(x - 48, y - 48, 96, 96), SDL_FLIP_NONE),
    (rect(192, 64, 64, 32), rect(x - 36, y,      96, 48), SDL_FLIP_NONE),
    (rect(192, 32, 64, 32), rect(x - 60, y,      96, 48), SDL_FLIP_NONE),
    (rect(  0,  0, 96, 96), rect(x - 48, y - 48, 96, 96), SDL_FLIP_NONE),
    (rect(192, 32, 64, 32), rect(x - 36, y,      96, 48), SDL_FLIP_NONE),
    (rect( 64, 96, 32, 32), rect(x - 18, y - 21, 36, 36), SDL_FLIP_NONE),
    (rect( 64, 96, 32, 32), rect(x - 6,  y - 21, 36, 36), SDL_FLIP_HORIZONTAL)]
  for part in bodyParts.mitems:
    renderer.copyEx(texture, part.src, part.dst, angle=0.0, center=nil, flip=part.flip)

proc newMap(texture: TexturePtr, file: string): Map =
  new result
  result.texture = texture
  result.tiles = @[]
  for line in file.lines:
    var width = 0
    for word in line.split(' '):
      if word == "": continue
      let value = parseUInt(word)
      if value > uint(uint8.high):
        raise ValueError.newException(
          "Invalid value " & word & " in map " & file)
      result.tiles.add(value.uint8)
      inc width
    if result.width > 0 and result.width != width:
      raise ValueError.newException(
        "Incompatible line length in map " & file)
    result.width = width
    inc result.height

proc renderMap(renderer: RendererPtr, map: Map, camera: Vector2Df) =
  var
    clip = rect(0, 0, tileSize.x, tileSize.y)
    dest = rect(0, 0, tileSize.x, tileSize.y)
  for i, tileNr in map.tiles:
    if tileNr == 0: continue
    clip.x = cint(tileNr mod tilesPerRow) * tileSize.x
    clip.y = cint(tileNr div tilesPerRow) * tileSize.y
    dest.x = cint(i mod map.width) * tileSize.x - camera.x.cint
    dest.y = cint(i div map.width) * tileSize.y - camera.y.cint
    renderer.copy(map.texture, unsafeAddr clip, unsafeAddr dest)

proc getTile(map: Map, x, y: int): uint8 =
  let
    nx = clamp(x div tileSize.x, 0, map.width - 1)
    ny = clamp(y div tileSize.y, 0, map.height - 1)
    pos = ny * map.width + nx
  map.tiles[pos]

proc getTile(map: Map, pos: Vector2Df): uint8 =
  map.getTile(pos.x.round.int, pos.y.round.int)

proc isSolid(map: Map, x, y: int): bool =
  map.getTile(x, y) notin {air, start, finish}

proc isSolid(map: Map, point: Vector2Df): bool =
  map.isSolid(point.x.round.int, point.y.round.int)

proc onGround(map: Map, pos: Vector2Df, size: Vector2D): bool =
  let
    size = size / 2
    lpt: Vector2Df = (pos.x - size.x.float, pos.y + size.y.float + 1)
    rpt: Vector2Df = (pos.x + size.x.float, pos.y + size.y.float + 1)
  map.isSolid(rpt) or map.isSolid(lpt)

proc testBox(map: Map, pos: Vector2Df, size: Vector2D): bool =
  let
    size = size / 2
    pt1 = (pos.x - size.x.float, pos.y - size.y.float)
    pt2 = (pos.x + size.x.float, pos.y - size.y.float)
    pt3 = (pos.x - size.x.float, pos.y + size.y.float)
    pt4 = (pos.x + size.x.float, pos.y + size.y.float)
  map.isSolid(pt1) or 
  map.isSolid(pt2) or 
  map.isSolid(pt3) or 
  map.isSolid(pt4)

proc moveBox(map: Map, pos, vel: var Vector2Df, size: Vector2D): set[Collision] {.discardable.} =
  let distance = vel.diag
  if distance < 0: return
  let maximum = distance.int
  let fraction = 1.0 / (distance.int.float + 1.0)
  for i in 0 .. maximum:
    var newPos = pos + vel * fraction
    if map.testBox(newPos, size):
      var hit = false
      if map.testBox(vector2Df(pos.x, newPos.y), size):
        result.incl Collision.y
        newPos.y = pos.y
        vel.y = 0.0
        hit = true
      if map.testBox(vector2Df(newPos.x, pos.y), size):
        result.incl Collision.x
        newPos.x = pos.x
        vel.x = 0.0
        hit = true
      if not hit:
        result.incl Collision.corner
        newPos = pos
        vel = (0.0, 0.0)
    pos = newPos

proc moveCamera(game: Game) =
  const halfWin = float(windowSize.x div 2)
  when defined(fluidCamera):
    let dist = game.camera.x - game.player.pos.x + halfWin
    game.camera.x -= 0.05 * dist
  elif defined(innerCamera):
    let
      leftArea  = game.player.pos.x - halfWin - 100
      rightArea = game.player.pos.x - halfWin + 100
    game.camera.x = clamp(game.camera.x, leftArea, rightArea)
  else:
    game.camera.x = game.player.pos.x - halfWin

proc formatTime(ticks: int): string =
  let
    mins = (ticks div 50) div 60
    secs = (ticks div 50) mod 60
  &"{mins:02}:{secs:02}"

proc formatTimeExact(ticks: int): string = 
    let cents = (ticks mod 50) * 2
    &"{formatTime(ticks)}:{cents:02}"

proc render(game: Game, tick: int) =
  game.renderer.clear()
  game.renderer.renderTee(game.player.texture,
    (game.player.pos - game.camera))
  game.renderer.renderMap(game.map, game.camera)

  let time = game.player.time
  const white = color(255, 255, 255, 255)
  if time.begin >= 0:
    game.renderTextCached(formatTimeExact(tick - time.begin), 50, 100, white)
  elif time.finish >= 0:
    game.renderTextCached("Finished in: " & formatTimeExact(time.finish), 50, 100, white)
  if time.best >= 0:
    game.renderTextCached("Best time: " & formatTimeExact(time.best), 50, 150, white)

  game.renderer.present()

proc restartPlayer(player: Player) =
  player.pos = (170.0, 300.0)
  player.vel = (  0.0,   0.0)
  player.time.begin = -1
  player.time.finish = -1

proc newTime: Time =
  new result
  result.finish = -1
  result.best = -1

proc newPlayer(texture: TexturePtr): Player =
  new result
  result.texture = texture
  result.time = newTime()
  result.restartPlayer()

proc newGame(renderer: RendererPtr): Game =
  new result
  result.camera = (0.0, 0.0)
  result.renderer = renderer
  result.player = newPlayer(renderer.loadTexture("player.png"))
  result.map = newMap(renderer.loadTexture("grass.png"), "default.map")
  result.font = openFont("../fonts/DejaVuSans.ttf", 28)
  sdlFailIf result.font.isNil: "Failed to load font"

proc toInput(key: Scancode): Input =
  case key
  of SDL_SCANCODE_A: Input.left
  of SDL_SCANCODE_D: Input.right
  of SDL_SCANCODE_SPACE: Input.jump
  of SDL_SCANCODE_R: Input.restart
  of SDL_SCANCODE_Q: Input.quit
  else: Input.none

proc handleInput(game: Game) =
  var event = defaultEvent
  while pollEvent(event):
    case event.kind
    of QuitEvent: game.inputs[Input.quit] = true
    of KeyDown:   game.inputs[event.key.keysym.scancode.toInput] = true
    of KeyUp:     game.inputs[event.key.keysym.scancode.toInput] = false
    else:         discard

proc logic(game: Game, tick: int) =
  template time: untyped = game.player.time
  case game.map.getTile(game.player.pos):
  of start:
    time.begin = tick
  of finish:
    if time.begin >= 0:
      time.finish = tick - time.begin
      time.begin = -1
      if time.best < 0 or time.finish < time.best:
        time.best = time.finish
      echo "Finished in ", formatTime(time.finish)
  else: discard

proc physics(game: Game) =
  if game.inputs[Input.restart]:
    game.player.restartPlayer()

  let ground = game.map.onGround(game.player.pos, playerSize)

  if game.inputs[Input.jump]:
    if ground:
      game.player.vel.y = -21.0
  
  let direction = float(game.inputs[Input.right].int - 
                        game.inputs[Input.left ].int)
  game.player.vel.y += 0.75
  if ground:
    game.player.vel.x = 0.5 * game.player.vel.x + 4.0 * direction
  else:
    game.player.vel.x = 0.95 * game.player.vel.x + 2.0 * direction
  game.player.vel.x = clamp(game.player.vel.x, -8, 8)
  game.map.moveBox(game.player.pos, game.player.vel, playerSize)





proc main =
  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
    "SDL2 initialization failed"
  defer: sdl2.quit()
  sdlFailIf(not setHint("SDL_RENDER_SCALE_QUALITY", "2")):
    "Linear texture filtering could not be enabled"  

  let window = createWindow(
    title = "Our own 2D platformer",
    x=SDL_WINDOWPOS_CENTERED, y=SDL_WINDOWPOS_CENTERED,
    w=1280, h=720, flags=SDL_WINDOW_SHOWN)
  sdlFailIf window.isNil: "Window could not be created"
  defer: window.destroy()

  let renderer = window.createRenderer(index = -1,
    flags=Renderer_Accelerated or Renderer_PresentVsync)
  sdlFailIf renderer.isNil: "Renderer could not be created"
  defer: renderer.destroy()
  renderer.setDrawColor(r=110, g=132, b=174)
  
  const imgFlags: cint = IMG_INIT_PNG
  sdlFailIf(image.init(imgFlags) != imgFlags):
    "SDL2 Image initialization failed"
  defer: image.quit()

  sdlFailIf(ttfInit() == SdlError): "SDL2 TTF initialization failed"
  defer: ttfQuit()

  var game = newGame(renderer)
  while not game.inputs[Input.quit]:
    game.handleInput()
    let newTick = int((epochTime() - startTime) * 50)
    for tick in lastTick+1 .. newTick:
      game.physics()
      game.moveCamera()
      game.logic(tick)
    lastTick = newTick
    game.render(lastTick)
    





main()