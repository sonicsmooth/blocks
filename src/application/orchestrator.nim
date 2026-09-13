import compact
import editor
import recttable
import pubsub
import reporting

type Orchestrator* = ref object
  editor*: Editor


proc newOrchestrator*(): Orchestrator = 
  new result

proc isReady*(self: Orchestrator): bool =
  if self.editor.isNil: return reportNil("orchestrator.editor")
  if not self.editor.isReady(): return reportNotReady("orchestrator.editor")
  true


proc blockRandomPos(self: Orchestrator) =
  echo "Orchestrator received random pos"
  if self.isReady():
    self.editor.doc.db.randomizeRectsPos(self.editor.dstRect)
    # self.editor.updateRatio()
    # self.editor.invalidate()


proc init*(self: Orchestrator) =
  registerListener(RandPos, proc() = self.blockRandomPos())
