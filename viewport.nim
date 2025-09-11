import sdl2

type
  ViewPort* = object
    pan*: Point
    zoom*: float

proc toPixel(vp: ViewPort, x, y: SomeNumber): Point =
  result = Point(0,0)