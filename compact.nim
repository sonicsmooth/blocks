import std/[tables, algorithm, sugar]
import wnim/wTypes
import rects

type 
  Axis* = enum X=true, Y=false
  Node = RectID
  Weight = int
  GraphEdge = tuple[frm, to: Node]
  Graph* = Table[GraphEdge, Weight]
  ScanEdgeType = enum Top, Bot
  ScanEdge = tuple[id: RectID, pos: int, etype: ScanEdgeType]
  ScanLine = tuple[pos: int, 
                   top: seq[RectID], 
                   mid: seq[RectID], 
                   bot: seq[RectID],
                   sorted: seq[RectID]]

const ROOTNODE: Node = "0"

type RectCmp = proc(r1, r2: Rect): int
proc RectCmpX(r1, r2: Rect): int = cmp(r1.x, r2.x)
proc RectCmpY(r1, r2: Rect): int = cmp(r1.y, r2.y)
proc RectCmpW(r1, r2: Rect): int = cmp(r1.width, r2.width)
proc RectCmpH(r1, r2: Rect): int = cmp(r1.height, r2.height)

proc sortRects(rects: openArray[Rect],
               ids: seq[RectID],
               rectCmp: RectCmp): seq[RectID] =
  var chosenRects: seq[Rect]
  for rect in rects: 
    if rect.id in ids: 
      chosenRects.add(rect)
  chosenRects.sort(rectCmp)
  for rect in chosenRects:
    result.add(rect.id)

# type RectGetter = proc(rect: Rect): int
# proc MakeDimGetter(axis: Axis): RectGetter =
#   if axis == X:
#     result = proc(rect: Rect): int = rect.width
#   elif axis == Y:
#     result = proc(rect: Rect): int = rect.height

type DimGetter2 = proc(node: Node): int
proc MakeDimGetter2(rectTable: RectTable, axis: Axis): DimGetter2 =
  if axis == X:
    proc(node: Node): int =
      #if node in rectTable:
      if node != ROOTNODE:
        result = rectTable[node].width
  else: # axis == Y:
    proc(node: Node): int =
      #if node in rectTable:
      if node != ROOTNODE:
        result = rectTable[node].height


# TODO: fix MakeDimGetter so it checks if src in rectTable else 0, etc.
proc ComposeGraph(lines: seq[ScanLine], 
                  rectTable: RectTable,
                  axis: Axis, 
                  reverse: bool): Graph = 
  #let wh = MakeDimGetter(axis)
  let getDim = MakeDimGetter2(rectTable, axis)
  for line in lines:
    var src: Node = "0"
    for dst in line.sorted:
      if dst in line.bot:
        continue
      let ge: GraphEdge = (src, dst)
      if ge notin result:
        if not reverse:
          result[ge] = src.getDim #if src in rectTable: rectTable[src].wh else: 0
        else:
          result[ge] = dst.getDim #if dst in rectTable: rectTable[dst].wh else: 0
      src = dst
    src = "0"
    for dst in line.sorted:
      if dst in line.top:
        continue
      let ge: GraphEdge = (src, dst)
      if ge notin result:
        if not reverse:
          result[ge] = src.getDim #if src in rectTable: rectTable[src].wh else: 0
        else:
          result[ge] = dst.getDim #if dst in rectTable: rectTable[dst].wh else: 0
      src = dst

proc ScanLines(rectTable: RectTable, axis: Axis, reverse: bool): seq[Lines] =
  discarde


proc MakeGraph(rectTable: RectTable, axis: Axis, reverse: bool): Graph =
  let lines = ScanLines(rectTable, axis, reverse)
  result = ComposeGraph(lines, rectTable, axis, reverse)
  # result = { ("1", "2"): 100,
  #            ("3", "4"): 200 }.toTable
  

proc longestPathBellmanFord(graph: Graph): Table[RectID, Weight] =
  result = { "1":  0, "2": 10, "3": 20, "4": 30,  "5": 40,
             "6": 50, "7": 60, "8": 70, "9": 80, "10": 90 }.toTable

proc compact*(rectTable: RectTable, axis: Axis, reverse: bool, clientSize: wSize) = 
  let graph = makeGraph(rectTable, axis, reverse)
  let lp = longestPathBellmanFord(graph)
  if axis == X and not reverse:
    for id, rect in rectTable:
      echo id
      rect.x = lp[id]
  elif axis == X and reverse:
    for id, rect in rectTable:
      rect.x = clientSize.width - lp[id]
  elif axis == Y and not reverse:
    for id, rect in rectTable:
      rect.y = lp[id]
  elif axis == Y and reverse:
    for id, rect in rectTable:
      rect.y = clientSize.height - lp[id]




