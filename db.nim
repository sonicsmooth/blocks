import recttable
export recttable

var
  gDb*: RectTable


proc initDb*() =
  gDb = RectTable()