
import rects

type 
  Axis* = enum X, Y
  Node = RectID
  Weight = int
  Graph* = HashSet[tuple[frm, to: Node], Weight]

proc makeGraph(rectTable: RectTable, axis: Axis, reverse: bool): Graph =
  false

proc longestPathBellmanFord(Graph: HashSet[RectID, int]) =
  discard

proc compact*(rectTable: RectTable, axis: Axis, reverse: bool) = 
  let graph = makeGraph(rectTable, axis, reverse)
  let lp = longestPathBellmanFord(graph)


