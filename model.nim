

type
  ModelUnit* = int
  Point* = tuple[x, y: ModelUnit]

converter toModelPoint*[T:SomeNumber](pt: tuple[x,y: T]): Point =
  result = (pt.x.ModelUnit, pt.y.ModelUnit)

# proc test1*(pt: Point) =
#   echo "test1"
#   echo pt