

type
  InnerT = tuple
    id: int32
  JunkT1 = tuple
    myint: int
    mystr: string
    myfloat: float
    iid: InnerT

var jt1: JunkT1 = (1, "hi", 2.3, (99,))
var jt2: JunkT1 = (2, "bye", 3.14, (101,))

echo "fieldPairs(jt1, jt2)"
for k,v1,v2 in fieldPairs(jt1, jt2):
  echo k, " -> (", v1, ", ", v2, ")"

echo ""
echo "fieldPairs(jt1)"
for k,v1 in fieldPairs(jt1):
  echo k, " -> ", v1

echo ""
echo "fields(jt1, jt2)"
for v1,v2 in fields(jt1, jt2):
  echo v1, " -> ", v2

echo ""
echo "fields(jt1)"
for v1 in fields(jt1):
  echo v1


proc sum(a: openArray[int]): int = 
  for i in 0 ..< a.len:
    result += a[i]

echo sum([1,2,3])


