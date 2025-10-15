import recttable
export recttable


## GLOBAL VAR FOR USE EVERYWHERE
var
  gDb*: RectTable


proc initDb*() =
  gDb = RectTable()