import wNim

type
  wFaultyPanelA = ref object of wPanel
    sbA, sbB, sbC: wStaticBox
    cb1: wComboBox
  wFaultyFrameA = ref object of wFrame
    mPanel: wFaultyPanelA
  wFaultyPanelB = ref object of wPanel
    sb1, sb2, sb3, sb4, sb5: wStaticBox
  wFaultyFrameB = ref object of wFrame
    mPanel: wFaultyPanelB

wClass(wFaultyPanelA of wPanel):
  proc init(self: wFaultyPanelA, parent: wWindow) =
    wPanel(self).init(parent)
    self.cb1 = ComboBox(self)
    self.sbA = StaticBox(self)
    self.sbB = StaticBox(self)
    self.sbC = StaticBox(self)
   
wClass(wFaultyFrameA of wFrame):
  proc init(self: wFaultyFrameA, parent: wWindow) =
    wFrame(self).init(parent)
    self.mPanel = FaultyPanelA(self)


wClass(wFaultyPanelB of wPanel):
  proc init(self: wFaultyPanelB, parent: wWindow) =
    wPanel(self).init(parent)
    self.sb1 = StaticBox(self)
    self.sb2 = StaticBox(self)
    self.sb3 = StaticBox(self)
    self.sb4 = StaticBox(self)
    self.sb5 = StaticBox(self)

wClass(wFaultyFrameB of wFrame):
  proc init(self: wFaultyFrameB, parent: wWindow) =
    wFrame(self).init(parent)
    self.mPanel = FaultyPanelB(self)
     
# method release*(self: wComboBox) =
#   echo "in method"
#   self.mParent.systemDisconnect(self.mCommandConn)
#   wasMoved(self.mEdit)
#   wasMoved(self.mList)
#   free(self[])

when isMainModule:
  let app = App()
  let appFrame = Frame(nil, title="Application Frame")

  appFrame.show()
  FaultyFrameA(appFrame).show()
  FaultyFrameB(appFrame).show()
  appFrame.close()
  #app.mainLoop()
