import std/strformat
import std/tables

type 
  Rect = ref object
    x: int
    y: int
  RectTableStringKey = Table[string, Rect]
  RefRectTableStringKey = ref Table[string, Rect]

  MyKeyType = float
  MyValueType = string

  XTableYKey = Table[MyKeyType, MyValueType]
  RefXTableYKey = ref Table[MyKeyType, MyValueType]



#var xx = (ref Rect)(x:15, y:20)

# proc `$`(rect: Rect): string =
#   result = fmt"Rect(x: {rect.x}, y: {rect.y})"

proc `$`[K,V](table: Table[K,V]): string = 
  result = fmt"hello from $Table[{$K}, {$V}]"

proc `$`[K,V](table: ref Table[K,V]): string = 
  result = fmt"hello from $refTable[{$K}, {$V}]"

var myTable1: RectTableStringKey
myTable1["one"] = Rect(x:10, y:20)
myTable1["two"] = Rect(x:15, y:25)

var myTable2: RefRectTableStringKey
new myTable2
myTable2["three"] = Rect(x:99, y:100)
myTable2["four"]  = Rect(x:909, y:109)

var myTable3: XTableYKey
myTable3[3.14159]  = "hello"
myTable3[2.78183] = "bye"

var myTable4: RefXTableYKey
new myTable4
myTable4[1.2345] = "dog"
myTable4[9.9998]  = "horse"

type 
  Field = enum NAME, AGE, HEIGHT
  MyPerson = tuple[name: string, age: int, height: int]

proc getField(x: MyPerson, field: Field): int =
  case field
    of AGE: x.age
    of HEIGHT: x.height
    else: 0

let myvar: MyPerson = ("what", 10, 45)
let myf1 = (field: AGE)
echo myvar.getField(myf1.field)