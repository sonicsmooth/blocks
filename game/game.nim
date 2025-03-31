import sdl2
import sdl2/image
import arraymancer


type
  SDLException = object of Exception
  Input {.pure.} = enum none, left, right, jump, restart, quit
  Coord = float
  Player = ref object
    texture: TexturePtr
    pos: Tensor[Coord]
    vel: Tensor[Coord]
  Game = ref object
    inputs: array[Input, bool]
    renderer: RendererPtr
    player: Player
    camera: Tensor[Coord]

template sdlFailIf(cond: typed, reason: string) =
  if cond: raise SDLException.newException(
    reason & ", SDL error: " & $getError())

proc renderTee(renderer: RendererPtr, texture: TexturePtr, pos: Tensor[Coord]) =
  let x = pos[0].cint
  let y = pos[1].cint
  var bodyParts: array[8, tuple[src, dst: Rect, flip: cint]] = [
    (rect(192, 64, 64, 32), rect(x-60, y,    96, 48), SDL_FLIP_NONE),
    (rect( 96,  0, 96, 96), rect(x-48, y-48, 96, 96), SDL_FLIP_NONE),
    (rect(192, 64, 64, 32), rect(x-36, y,    96, 48), SDL_FLIP_NONE),
    (rect(192, 32, 64, 32), rect(x-60, y,    96, 48), SDL_FLIP_NONE),
    (rect(  0,  0, 96, 96), rect(x-48, y-48, 96, 96), SDL_FLIP_NONE),
    (rect(192, 32, 64, 32), rect(x-36, y,    96, 48), SDL_FLIP_NONE),
    (rect( 64, 96, 32, 32), rect(x-18, y-21, 96, 36), SDL_FLIP_NONE),
    (rect( 64, 96, 32, 32), rect(x-6,  y-6,  96, 36), SDL_FLIP_HORIZONTAL)]
  for part in bodyParts.mitems:
    renderer.copyEx(texture, part.src, part.dst, angle=0.0, center=nil, flip=part.flip)

proc render(game: Game) =
  game.renderer.clear()
  game.renderer.renderTee(game.player.texture,
    game.player.pos - game.camera)
  game.renderer.present()

proc restartPlayer(player: Player) =
  player.pos = [Coord(170), 500].toTensor()
  player.vel = [Coord(0),     0].toTensor()

proc newPlayer(texture: TexturePtr): Player =
  new result
  result.texture = texture
  result.restartPlayer()

proc newGame(renderer: RendererPtr): Game =
  new result
  result.renderer = renderer
  result.player = newPlayer(renderer.loadTexture("player.png"))
  result.camera = [Coord(0),0].toTensor()

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
    game.render()



main()