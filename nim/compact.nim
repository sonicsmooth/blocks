import std/[tables, algorithm, sugar]
from sequtils import concat
import wnim/wTypes
import rects

type 
  Axis* = enum X=true, Y=false
  MajMin = enum Major=true, Minor=false
  Node = RectID
  Weight = int
  GraphEdge = tuple[frm, to: Node]
  Graph* = Table[GraphEdge, Weight]
  ScanEdgeType = enum Top, Bot
  ScanFieldType = enum Top, Mid, Bot
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

proc getField(line: ScanLine, field: ScanFieldType): seq[RectId] =
  case field
    of Top: line.top
    of Mid: line.mid
    of Bot: line.bot

proc setField(var line: ScanLine, field: ScanFieldType, val: seq[RectId]) =
  case field
    of Top: line.top
    of Mid: line.mid
    of Bot: line.bot

type DimGetter = proc(node: Node): int
proc MakeDimGetter(rectTable: RectTable, axis: Axis): DimGetter =
  if axis == X:
    proc(node: Node): int =
      if node != ROOTNODE:
        result = rectTable[node].width
  else: # axis == Y:
    proc(node: Node): int =
      if node != ROOTNODE:
        result = rectTable[node].height


proc ComposeGraph(lines: seq[ScanLine], rectTable: RectTable,
                  axis: Axis, reverse: bool): Graph = 
  let getDim = MakeDimGetter(rectTable, axis)
  var src: Node
  for line in lines:
    src = ROOTNODE
    for dst in line.sorted:
      if dst in line.bot: continue
      if (src, dst) notin result:
        result[(src, dst)] = if reverse: dst.getDim else: src.getDim
      src = dst

    src = ROOTNODE
    for dst in line.sorted:
      if dst in line.top: continue
      if (src, dst) notin result:
        result[(src, dst)] = if reverse: dst.getDim else: src.getDim
      src = dst

proc PosChooser(ax: MajMin): proc(rect: Rect): int =
  if ax == Major:
    proc(rect: Rect): int =  rect.x
  else:
    proc(rect: Rect): int =  rect.y

proc SizeChooser(ax: MajMin): proc(rect: Rect): int =
  if ax == Major:
    proc(rect: Rect): int = rect.width
  else:
    proc(rect: Rect): int = rect.height


proc ScanLines(rectTable: RectTable, axis: Axis, reverse: bool): seq[ScanLine] =
  let 
    PrimPos = PosChooser(Major)
    PrimSz  = SizeChooser(Major)
    SecPos  = PosChooser(Minor)
    SecSz   = PosChooser(Minor)
    topEdges: seq[ScanEdge] = 
      collect(for rect in rectTable.values:
        (id: rect.id, pos: rect.SecPos, etype: Top))
    botEdges: seq[ScanEdge] = 
      collect(for rect in rectTable.values:
        (id: rect.id, pos: rect.SecPos + rect.SecSz, etype: Bot))
    edges: seq[ScanEdge] = concat(topEdges, botEdges)

  # Prime everything with first edge
  var edge: ScanEdge  = edges[0]
  var line: ScanLine = (pos: edge.pos, 
                        top: @[], mid: @[], bot: @[], 
                        sorted: @[edge.id])




proc MakeGraph(rectTable: RectTable, axis: Axis, reverse: bool): Graph =
  let lines = ScanLines(rectTable, axis, reverse)
  result = ComposeGraph(lines, rectTable, axis, reverse)
  # result = { ("1", "2"): 100,
  #            ("3", "4"): 200 }.toTable
  

proc longestPathBellmanFord(graph: Graph): Table[RectID, Weight] =
  result = { "1":  0, "2": 10, "3": 20, "4": 30,  "5": 40,
             "6": 50, "7": 60, "8": 70, "9": 80, "10": 90 }.toTable

proc compact*(rectTable: RectTable, axis: Axis, reverse: bool, clientSize: wSize) = 
  let graph = MakeGraph(rectTable, axis, reverse)
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




