import recttable, grid, reporting
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

proc isReady*(self: Document): bool =
  if self.db.isNil: return reportNil("document.db")
  if self.grid.isNil: return reportNil("document.grid")
  if not self.grid.isReady(): return reportNotReady("document.grid")
  true


when isMainModule:
  let doc: Document = newDocument()
  echo doc[]