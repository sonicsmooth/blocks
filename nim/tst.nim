import std/strformat
import std/tables

type Rect = object
  x: int
  y: int

proc `$`(rect: ref Rect): string =
  inc(rect.x)
  result = fmt"[{rect.x}, {rect.y}]"

proc `$`(rect: ref Rect, i: int): string =
  inc(rect.x, i)
  result = fmt"[{rect.x}, {rect.y}]"

var xx = (ref Rect)(x:15, y:20)

type RectTable = Table[string, string]


var tab:RectTable = {"hi":"cat", "bye":"horse"}.toTable()


var mRefRectTable: ref RectTable
new mRefRectTable
mRefRectTable[] = tab
# echo mRefRectTable[]
# echo type(mRefRectTable)
# echo type(mRefRectTable["hi"])

var rf = mRefRectTable
echo rf
rf["hi"] = "monitor"

echo mRefRectTable[]
echo rf[]

var bla: array[0,int]
if bla.len == 0:
  echo "ya"
