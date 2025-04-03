

type Point2D = tuple[x, y: int]

let pt1 = Point2D(1,2)
let pt2: Point2D = (1,2)
assert pt1 == pt2