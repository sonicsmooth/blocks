import std/strformat

type Rect = object
  x: int
  y: int

proc `$`(rect: ref Rect): string =
  inc(rect.x)
  result = fmt"[{rect.x}, {rect.y}]"

proc `$`(rect: ref Rect, i: int): string =
  inc(rect.x, i)
  result = fmt"[{rect.x}, {rect.y}]"


