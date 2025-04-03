import strutils, times, math
import sdl2
import sdl2/image
#import arraymancer


type
  SDLException = object of Exception
  Input {.pure.} = enum none, left, right, jump, restart, quit
  Vector2D = tuple[x, y: cint]
  Vector2Df = tuple[x, y: float]
  Player = ref object
    texture: TexturePtr
    pos: Vector2Df
    vel: Vector2Df
  Map = ref object
    texture: TexturePtr
    width, height: int
    tiles: seq[uint8]
  Collision {.pure.} = enum x, y, corner
  Game = ref object
    inputs: array[Input, bool]
    renderer: RendererPtr
    player: Player
    map: Map
    camera: Vector2Df

const
  tilesPerRow = 16
  tileSize: Vector2D = (64, 64)
  playerSize: Vector2D = (64, 64)
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

proc `+=`[T:Vector2D|Vector2Df](v1: var T, v2: T) =
  v1.x = v1.x + v2.x
  v1.y = v1.y + v2.y

proc `-=`[T:Vector2D|Vector2Df](v1: var T, v2: T) =
  v1.x = v1.x - v2.x
  v1.y = v1.y - v2.y

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

proc vector2D(x,y: cint): Vector2D =
  (x, y)

proc vector2Df(x,y: cint): Vector2Df =
  (x.float, y.float)

proc vector2Df(x,y: float): Vector2Df =
  (x, y)

proc diag[T:Vector2D|Vector2Df](v1: T): float =
  sqrt(v1.x.float^2 + v1.y.float^2)

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

proc render(game: Game) =
  game.renderer.clear()
  game.renderer.renderTee(game.player.texture,
    (game.player.pos - game.camera))
  game.renderer.renderMap(game.map, game.camera)
  game.renderer.present()

proc restartPlayer(player: Player) =
  player.pos = (170.0, 500.0)
  player.vel = (  0.0,   0.0)

proc newPlayer(texture: TexturePtr): Player =
  new result
  result.texture = texture
  result.restartPlayer()

proc newGame(renderer: RendererPtr): Game =
  new result
  result.camera = (0.0, 0.0)
  result.renderer = renderer
  result.player = newPlayer(renderer.loadTexture("player.png"))
  result.map = newMap(renderer.loadTexture("grass.png"), "default.map")

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
  #game.player.pos += game.player.vel
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

  var game = newGame(renderer)
  while not game.inputs[Input.quit]:
    game.handleInput()
    let newTick = int((epochTime() - startTime) * 50)
    for tick in lastTick+1 .. newTick:
      game.physics()
    lastTick = newTick
    game.render()
    





main()