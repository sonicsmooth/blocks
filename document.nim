import recttable, grid
export recttable, grid

type
  # Fields here get saved to disk
  Document* = ref object of RootObj
    db*: RectTable
    grid*: Grid

proc newDocument*(): Document =
  result = new Document
  result.db = RectTable()
  let zc = newZoomCtrl(base=5, clickDiv=2400, maxPwr=5, density=1.0, dynamic=true, baseSync=true)
  result.grid = newGrid(zCtrl=zc)

when isMainModule:
  let doc: Document = newDocument()
  echo doc[]