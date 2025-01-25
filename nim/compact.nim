import std/[tables, sets, algorithm]
from std/sugar import collect
from sequtils import concat, delete, toSeq
import wnim/wTypes
import rects

type 
  Axis* = enum X=true, Y=false
  MajMin = enum Major=true, Minor=false
  Node = RectID
  Weight = int
  GraphEdge = tuple[frm, to: Node]
  Graph* = Table[GraphEdge, Weight]
  ScanType = enum Top, Mid, Bot
  ScanEdge = tuple[id: RectID, pos: int, etype: ScanType]
  ScanLine = tuple[pos: int,        
                   top: seq[RectID],
                   mid: seq[RectID],
                   bot: seq[RectID],
                   sorted: seq[RectID]]

const ROOTNODE: Node = "0"

#type RectCmp = proc(r1, r2: Rect): int
proc RectCmpX(r1, r2: Rect): int = cmp(r1.x, r2.x)
proc RectCmpY(r1, r2: Rect): int = cmp(r1.y, r2.y)
# proc RectCmpW(r1, r2: Rect): int = cmp(r1.width, r2.width)
# proc RectCmpH(r1, r2: Rect): int = cmp(r1.height, r2.height)
proc SortedRectsIds(rects: seq[Rect], axis: Axis, reverse: bool): seq[RectID] =
  # Returns rect ids with compare chosen by axis
  var tmpRects = rects
  let order = if reverse: Descending else: Ascending
  if axis == X:
    tmpRects.sort(RectCmpX, order)
  else:
    tmpRects.sort(RectCmpY, order)
  result = tmpRects.ids

proc setField[T](line: var ScanLine, field: ScanType, val: T) =
  case field
    of Top: line.top = val
    of Mid: line.mid = val
    of Bot: line.bot = val

proc appendField[T](line: var ScanLine, field: ScanType, val: T) =
  case field
    of Top: line.top.add(val)
    of Mid: line.mid.add(val)
    of Bot: line.bot.add(val)

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
    minor = if axis==X: Minor else: Major
    SecPos  = PosChooser(minor)
    SecSz   = SizeChooser(minor)
    topEdges: seq[ScanEdge] = 
      collect(for rect in rectTable.values:
        (id: rect.id, pos: rect.SecPos, etype: Top))
    botEdges: seq[ScanEdge] = 
      collect(for rect in rectTable.values:
        (id: rect.id, pos: rect.SecPos + rect.SecSz, etype: Bot))
    edges: seq[ScanEdge] = concat(topEdges, botEdges).sortedByIt(it.pos)
  
  # Prime everything with first edge
  var edge: ScanEdge  = edges[0]
  var line: ScanLine  = (pos: edge.pos, 
                         top: @[], mid: @[], bot: @[], 
                         sorted: @[edge.id])
  line.setField(edge.etype, @[edge.id])
  var lastpos = edge.pos

  # Go through each edge
  # Push accumulated line when next line detected
  for i, edge in edges[1..high(edges)]:
    if edge.pos > lastpos: # down one edge
      result.add(line)
      line.pos = edge.pos
      line.bot = @[]
      line.mid.add(line.top)
      line.top = @[]

    if edge.etype == Bot and edge.id in line.mid:
      line.mid.delete(line.mid.find(edge.id))
    line.appendField(edge.etype, edge.id)

    line.sorted = concat(line.top, line.mid, line.bot)
    if line.sorted.len > 1:
      line.sorted = SortedRectsIds(rectTable[line.sorted], axis, reverse)
    if line.top.len > 1:
      line.top = SortedRectsIds(rectTable[line.top], axis, reverse)
    if line.bot.len > 1:
      line.bot = SortedRectsIds(rectTable[line.bot], axis, reverse)
    lastpos = edge.pos
  result.add(line)

proc MakeGraph*(rectTable: RectTable, axis: Axis, reverse: bool): Graph =
  # Returns DAG = table((frm,to): weight)
  # rectTable is table of rects
  # axis is X or Y
  # reverse is left/up or down/right
  let lines = ScanLines(rectTable, axis, reverse)
  result = ComposeGraph(lines, rectTable, axis, reverse)
  
# proc NodeSet(graph: Graph): HashSet[Node] =
#   for edge in graph.keys:
#     result.incl(edge.frm)
#     result.incl(edge.to)

proc longestPathBellmanFord(graph: Graph, nodes: openArray[Node]): Table[RectID, Weight] =
  for node in nodes:
    result[node] = Weight.low
  result[ROOTNODE] = 0

  for iter in 1..nodes.len:
    for edge, weight in graph:
      let frm = edge[0]
      let to = edge[1]
      if result[frm] == Weight.low:
        continue
      result[to] = max(result[to], result[frm] + weight)
  result.del(ROOTNODE)
  echo result

proc compact*(rectTable: RectTable, axis: Axis, reverse: bool, clientSize: wSize) = 
  echo clientSize
  let graph = MakeGraph(rectTable, axis, reverse)
  let nodes = rectTable.values.toSeq.ids
  let lp = longestPathBellmanFord(graph, nodes)
  if axis == X and not reverse:
    for id, rect in rectTable:
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




