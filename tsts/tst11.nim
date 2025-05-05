

type
  Junk = tuple
    a: int
    b: int
  Point = tuple
    x: int
    y: int


proc plus(p: Point): Point =
  (p.x+1, p.y+1)

# converter toPoint(p: tuple[a: int, b: int]): Point =
#   echo "converter"
#   (x: p.a, y: p.b)

let p: Junk = (10,20)
echo p
echo p.Point
