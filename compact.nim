import std/[algorithm, locks, sugar, tables]
import sequtils
import wnim
import wnim/wTypes
import winim/inc/winuser
import concurrent
import recttable, userMessages

type 
  Axis* = enum X=true, Y=false
  MajMin = enum Major=true, Minor=false
  Node = RectID
  Weight = int
  GraphEdge  = tuple[frm, to: Node]
  Graph* = Table[GraphEdge, Weight]
  ScanType = enum Top, Mid, Bot
  ScanEdge = tuple
    id:    RectID
    pos:   int
    etype: ScanType
  ScanLine = tuple
    pos:    int        
    top:    seq[RectID]
    mid:    seq[RectID]
    bot:    seq[RectID]
    sorted: seq[RectID]
  CompactDir* = tuple
    primax,  secax:  Axis
    primAsc, secAsc: SortOrder
  CompoundDir* = enum UpLeft,UpRight,DownLeft,DownRight,LeftUp,LeftDown,RightUp,RightDown
  CompactArg* = tuple
    pRectTable: ptr RectTable
    direction:  CompactDir
    window:     wWindow
    dstRect:    wRect


const
  RootNode = when RectID is string: "0" else: 0

var
  gCompactThread*: Thread[CompactArg]

proc compoundDir*(cd: CompactDir): CompoundDir =
  let compound = (cd.primax == X, cd.primAsc, cd.secAsc)
  if   compound == (false, Ascending,  Ascending ): UpLeft
  elif compound == (false, Ascending,  Descending): UpRight
  elif compound == (false, Descending, Ascending ): DownLeft
  elif compound == (false, Descending, Descending): DownRight
  elif compound == (true,  Ascending,  Ascending ): LeftUp
  elif compound == (true,  Ascending,  Descending): LeftDown
  elif compound == (true,  Descending, Ascending ): RightUp
  else: RightDown
  
proc isXAscending*(direction: CompactDir): bool =
  (direction.primax == X and direction.primAsc == Ascending) or
  (direction.secax  == X and direction.secAsc  == Ascending)

proc isYAscending*(direction: CompactDir): bool = 
  (direction.primax == Y and direction.primAsc == Ascending) or
  (direction.secax  == Y and direction.secAsc  == Ascending)

proc rectCmpX(r1, r2: Rect): int = 
  # Sort first by x position, then by id
  result = cmp(r1.x, r2.x)
  if result == 0:
    result = cmp(r1.id, r2.id)

proc rectCmpY(r1, r2: Rect): int = 
  # Sort first by y position, then by id
  result = cmp(r1.y, r2.y)
  if result == 0:
    result = cmp(r1.id, r2.id)

# TODO: change to in-place sorting
proc sortedRectsIds(rects: seq[Rect], axis: Axis, sortOrder: SortOrder): seq[RectID] =
  # Returns rect ids with compare chosen by axis
  var tmpRects = rects
  if axis == X:
    tmpRects.sort(rectCmpX, sortOrder)
  else:
    tmpRects.sort(rectCmpY, sortOrder)
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
      if node != RootNode:
        result = rectTable[node].wRect.width
  else: # axis == Y:
    proc(node: Node): int =
      if node != RootNode:
        result = rectTable[node].wRect.height

proc ComposeGraph(lines: seq[ScanLine], rectTable: RectTable,
                  axis: Axis, sortOrder: SortOrder): Graph = 
  let getDim = MakeDimGetter(rectTable, axis)
  var src: Node
  for line in lines:
    src = RootNode
    for dst in line.sorted:
      if dst in line.bot: continue
      if (src, dst) notin result:
        result[(src, dst)] = if sortOrder == Descending: dst.getDim else: src.getDim
      src = dst
    src = RootNode
    for dst in line.sorted:
      if dst in line.top: continue
      if (src, dst) notin result:
        result[(src, dst)] = if sortOrder == Descending: dst.getDim else: src.getDim
      src = dst

proc PosChooser(ax: MajMin): proc(rect: Rect): int =
  if ax == Major:
    proc(rect: Rect): int =  rect.x
  else:
    proc(rect: Rect): int =  rect.y

proc SizeChooser(ax: MajMin): proc(rect: Rect): int =
  if ax == Major:
    proc(rect: Rect): int = rect.wRect.width
  else:
    proc(rect: Rect): int = rect.wRect.height

proc ScanLines(rectTable: RectTable, axis: Axis, sortOrder: SortOrder, ids: seq[RectID]): seq[ScanLine] =
  let 
    minor = if axis==X: Minor else: Major
    SecPos  = PosChooser(minor)
    SecSz   = SizeChooser(minor)
    colids  = if ids.len == 0: rectTable.keys.toSeq
             else:             ids
    topEdges: seq[ScanEdge] = 
        collect(for id in colids:
          (id: id, pos: rectTable[id].SecPos, etype: Top))
    botEdges: seq[ScanEdge] = 
        collect (for id in colids:
          let rect = rectTable[id]
          (id: id, pos: rect.SecPos + rect.SecSz, etype: Bot))
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
      line.bot = @[] # TODO: profile vs. setLen(0)
      line.mid.add(line.top)
      line.top = @[]

    if edge.etype == Bot and edge.id in line.mid:
      line.mid.delete(line.mid.find(edge.id))
    line.appendField(edge.etype, edge.id)

    line.sorted = concat(line.top, line.mid, line.bot)
    if line.sorted.len > 1:
      line.sorted = sortedRectsIds(rectTable[line.sorted], axis, sortOrder)
    if line.top.len > 1:
      line.top = sortedRectsIds(rectTable[line.top], axis, sortOrder)
    if line.bot.len > 1:
      line.bot = sortedRectsIds(rectTable[line.bot], axis, sortOrder)
    lastpos = edge.pos
  result.add(line)

proc MakeGraph*(rectTable: RectTable, axis: Axis, sortOrder: SortOrder, ids: seq[RectID]): Graph =
  # Returns DAG = table((frm,to): weight)
  # rectTable is table of rects
  # axis is X or Y
  # sortOrder == left/up or down/right
  let lines = ScanLines(rectTable, axis, sortOrder, ids)
  result = ComposeGraph(lines, rectTable, axis, sortOrder)

proc longestPathBellmanFord(graph: Graph, nodes: openArray[Node], minpos: int): Table[RectID, Weight] =
  for node in nodes:
    result[node] = Weight.low
  result[RootNode] = minpos

  for iter in 0..nodes.len:
    for ge, weight in graph:
      if result[ge.frm] == Weight.low:              
        continue
      result[ge.to] = max(result[ge.to], result[ge.frm] + weight)
  result.del(RootNode)

proc compact*(rectTable: RectTable, 
              axis: Axis,
              sortOrder: SortOrder,
              dstRect: wRect,
              ids: seq[RectID] = @[]) =
  # Top level compact function in one direction
  let graph = MakeGraph(rectTable, axis, sortOrder, ids)
  let nodes = if ids.len == 0: rectTable.keys.toSeq
              else: ids

  if axis == X and sortOrder == Ascending:
    let lp = longestPathBellmanFord(graph, nodes, 0)
    for id in nodes:
      rectTable[id].x = dstRect.x + lp[id]

  elif axis == X and sortOrder == Descending:
    let lp = longestPathBellmanFord(graph, nodes, 0)
    for id in nodes:
      rectTable[id].x = dstRect.x + dstRect.width - lp[id]

  elif axis == Y and sortOrder == Ascending:
    let lp = longestPathBellmanFord(graph, nodes, 0)
    for id in nodes:
      rectTable[id].y = dstRect.y + lp[id]

  elif axis == Y and sortOrder == Descending:
    let lp = longestPathBellmanFord(graph, nodes, 0)
    for id in nodes:
      rectTable[id].y = dstRect.y + dstRect.height - lp[id]

proc iterCompact*(rectTable: RectTable, direction: CompactDir, dstRect: wRect) =
  # Run compact function until rectTable doesn't change
  var pos, lastPos: PosTable
  pos = rectTable.positions
  while pos != lastPos:
    compact(rectTable, direction.primax, direction.primAsc, dstRect)
    compact(rectTable, direction.secax, direction.secAsc, dstRect)
    lastPos = pos
    pos = rectTable.positions

proc compactWorker*(arg: CompactArg) {.thread.} =
  {.gcsafe.}:
    withLock(gLock):
      iterCompact(arg.pRectTable[], arg.direction, arg.dstRect)
  PostMessage(arg.window.mHwnd, USER_ALG_UPDATE, 0, 0)
  