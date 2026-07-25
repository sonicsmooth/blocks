import std/[algorithm, locks, math, segfaults, sets, strformat, tables ]
from std/sequtils import toSeq, foldl
import editor, renderer
import wNim
import winim
import anneal, appopts, compact, concurrent, document
import stack, userMessages, utils, blockpanel, world
import reporting
export blockpanel

# TODO: mainpanel should have refs to editor, renderer, doc

type
  wMainPanel* = ref object of wPanel
    blockPanel*: wBlockPanel
    spnr:  wSpinCtrl
    txt:   wStaticText
    box1:  wStaticBox
    ctrb1: wRadioButton # Compact type radio button
    ctrb2: wRadioButton # Compact type radio button
    ctrb3: wRadioButton # Compact type radio button
    aStratRb1: wRadioButton # Anneal strategy radio button
    aStratRb2: wRadioButton # Anneal strategy radio button
    aStratRb3: wRadioButton # Anneal strategy radio button
    aStratRb4: wRadioButton # Anneal strategy radio button
    slider*: wSlider
    buttons: array[17, wButton]

const 
  logRandomize = true
  randRegion: WRect = (-400, -400, 801, 801)


wClass(wMainPanel of wPanel):
  proc isReady*(self: wMainPanel): bool =
    if self.blockPanel.isNil: return reportNil("wMainPanel.blockPanel")
    if self.spnr.isNil: return reportNil("wMainPanel.spnr")
    if self.txt.isNil: return reportNil("wMainPanel.txt")
    if self.box1.isNil: return reportNil("wMainPanel.box1")
    if self.ctrb1.isNil: return reportNil("wMainPanel.ctrb1")
    if self.ctrb2.isNil: return reportNil("wMainPanel.ctrb2")
    if self.ctrb3.isNil: return reportNil("wMainPanel.ctrb3")
    if self.aStratRb1.isNil: return reportNil("wMainPanel.aStratRb1")
    if self.aStratRb2.isNil: return reportNil("wMainPanel.aStratRb2")
    if self.aStratRb3.isNil: return reportNil("wMainPanel.aStratRb3")
    if self.aStratRb4.isNil: return reportNil("wMainPanel.aStratRb4")
    if self.slider.isNil: return reportNil("wMainPanel.slider")
    if not self.blockPanel.isReady(): return reportNotReady("wMainPanel.blockPanel")
    true

  proc layout*(self: wMainPanel) =
    let 
      bmarg = self.dpiScale(8)
      (cszw, cszh) = self.clientSize
      (bw, bh) = (self.dpiScale(150), self.dpiScale(30))
      (lbpmarg, rbpmarg, tbpmarg, bbpmarg) = (0, 8, 0, 0)
      bwd2 = bw div 2
    if self.blockPanel != nil:
      self.blockPanel.position = (bw + 2*bmarg + lbpmarg, tbpmarg)
      self.blockPanel.size = (cszw - bw - 2*bmarg - lbpmarg - rbpmarg, 
                               cszh - tbpmarg - bbpmarg)
    var yPosAcc = 0
    # Static text position, size
    self.txt.position = (bmarg, bmarg)
    self.txt.size = (bwd2, self.txt.size.height)

    # Spin Ctrl position, size
    self.spnr.position = (bmarg + bwd2, bmarg)
    self.spnr.size     = (bwd2, self.spnr.size.height)
    yPosAcc += bmarg + self.txt.size.height

    # Selection strategy pos, size
    self.ctrb1.position = (bmarg,            yPosAcc); yPosAcc += bh
    self.ctrb2.position = (bmarg,            yPosAcc)
    self.ctrb3.position = (bmarg + bwd2, yPosAcc)

    self.ctrb1.size     = (bw,       bh)
    self.ctrb2.size     = (bwd2, bh)
    self.ctrb3.size     = (bwd2, bh)
    yPosAcc += bmarg + bh

    # Slider position, size
    self.slider.position = (bmarg, yPosAcc)
    self.slider.size    = (bw, bh)
    yPosAcc += bmarg + bh

    # Static box1 and radio button position, size
    self.box1.position  = (bmarg,   yPosAcc          )
    self.aStratRb1.size = (bwd2, bh)
    self.aStratRb2.size = (bwd2, bh)
    self.aStratRb3.size = (bwd2, bh)
    self.aStratRb4.size = (bwd2, bh)
    self.aStratRb1.position = (bmarg*2, yPosAcc + bmarg*3); #yPosAcc += self.aStratRb1.size.height
    self.aStratRb3.position = (bmarg*2+bwd2, yPosAcc + bmarg*3); yPosAcc += self.aStratRb3.size.height
    self.aStratRb2.position = (bmarg*2, yPosAcc + bmarg*3); #yPosAcc += self.aStratRb2.size.height
    self.aStratRb4.position = (bmarg*2+bwd2, yPosAcc + bmarg*3); yPosAcc += self.aStratRb4.size.height
    self.box1.size = (bw, self.aStratRb1.size.height*2 + bmarg*4)
    yPosAcc += bmarg*5

    # Buttons position, size
    for i, butt in self.buttons:
      butt.position = (bmarg, yPosAcc)
      butt.size     = (bw, bh)
      yPosAcc += bh

  # TODO: Move this to algorithms or db or something
  # TODO: Since nothing here has to do with UI
  proc randomizeRectsAll*(self: wMainPanel, qty: int=self.spnr.value) =
    # TODO: delegate all this to something else, so we can 
    # TODO: get rid of self.blockpanel.editor,... etc.
    # if self.blockPanel != nil and
    #    self.blockPanel.editor != nil and
    #    self.blockPanel.editor.doc != nil:
    if self.isReady():
      var db = self.blockPanel.editor.doc.db
      db.randomizeRectsAll(randRegion, qty, logRandomize)
      ##! Move updateRatio to algorithm, solve clearTextureCache
      self.blockPanel.editor.fillArea = db.fillArea()
      self.blockPanel.editor.updateRatio()
      # if self.blockPanel.renderer != nil:
      self.blockPanel.renderer.clearTextureCache()

  proc delegate1DButtonCompact(self: wMainPanel, axis: Axis, sortOrder: SortOrder) = 
    #echo GC_getStatistics()
    ##! Move updateratio to algorithm
    if self.blockPanel != nil:
      var db = self.blockPanel.editor.doc.db
      withLock(gLock):
        compact(db, axis, sortOrder, self.blockPanel.editor.dstRect)
      self.blockPanel.editor.updateRatio()
      self.refresh(false)
      GC_fullCollect()

  proc delegate2DButtonCompact(self: wMainPanel, direction: CompactDir) =
    # Leave if we have any threads already running
    if self.blockPanel.isNil: return
    if gCompactThread.running: return
    for i in gAnnealComms.low .. gAnnealComms.high:
      if gAnnealComms[i].thread.running: return
    let dstRect = self.blockPanel.editor.dstRect
    let dbaddr = addr self.blockPanel.editor.doc.db
    
    if self.ctrb1.value: # Not anneal, just normal 2d compact
      let arg: CompactArg = (pRectTable:  dbaddr,
                             direction:   direction,
                             window:      self,
                             dstRect:     dstRect)
      gCompactThread.createThread(compactWorker, arg)
      gCompactThread.joinThread()
      self.blockPanel.editor.updateRatio()
      self.refresh(false)
   
    elif self.ctrb2.value: # Do anneal
      proc compactfn() {.closure.} = 
        iterCompact(self.blockPanel.editor.doc.db, direction, dstRect)
      let strat = if self.aStratRb1.value: Strat1
                  else:                     Strat2
      let perturbFn = if self.aStratRb3.value: makeWiggler[PosTable, ptr RectTable](dstRect)
                      else:                     makeSwapper[PosTable, ptr RectTable]()
      for i in gAnnealComms.low .. gAnnealComms.high:
        let arg: AnnealArg = (pRectTable: dbaddr,
                              strategy:   strat,
                              initTemp:   self.slider.value.float,
                              perturbFn:  perturbFn,
                              compactFn:  compactfn,
                              window:     self,
                              dstRect:    dstRect,
                              comm:       gAnnealComms[i])
        # Weird, TODO: just do once
        gAnnealComms[i].thread.createThread(annealMain, arg)
        # TODO: figure out how to clearTextureCache when thread is done
        break
    
    elif self.ctrb3.value: # Do stack
      withLock(gLock):
        stackCompact(self.blockPanel.editor.doc.db, dstRect, direction)
      self.blockPanel.renderer.clearTextureCache()
      self.blockPanel.editor.updateRatio()
      self.refresh(false)

  proc onResize(self: wMainPanel, event: wEvent) =
    self.layout()
    event.skip()

  proc onSpinSpin(self: wMainPanel, event: wEvent) =
    let qty = event.getSpinPos() + event.getSpinDelta()
    self.randomizeRectsAll(qty)
    if self.blockPanel != nil:
      self.blockPanel.editor.updateRatio()
    self.refresh(false)

  proc onSpinTextEnter(self: wMainPanel) =
    if self.spnr.value > 0:
      self.randomizeRectsAll(self.spnr.value)
      if self.blockPanel != nil:
        self.blockPanel.editor.updateRatio()
      self.refresh(false)

  proc onStrategyRadioButton(self: wMainPanel, event: wEvent) =
    if self.ctrb1.value: # No strategy
      self.slider.disable()
      self.aStratRb1.disable()
      self.aStratRb2.disable()
      self.aStratRb3.disable()
      self.aStratRb4.disable()
    elif self.ctrb2.value: # Anneal strategy
      self.slider.enable()
      self.aStratRb1.enable()
      self.aStratRb2.enable()
      self.aStratRb3.enable()
      self.aStratRb4.enable()
    elif self.ctrb3.value: # Stack strategy
      self.slider.disable()
      self.aStratRb1.disable()
      self.aStratRb2.disable()
      self.aStratRb3.disable()
      self.aStratRb4.disable()

  proc onSlider(self: wMainPanel, event: wEvent) =
    let pos = event.scrollPos
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hwnd, idMsgSlider, pos, pos)

  proc onButtonrandomizeAll(self: wMainPanel) =
    if self.blockPanel != nil:
      self.randomizeRectsAll(self.spnr.value)
      self.blockPanel.editor.updateRatio()
      self.refresh(false)
  
  proc onButtonrandomizePos(self: wMainPanel) =
    if self.blockPanel != nil:
      #let sz = self.blockPanel.clientSize
      self.blockPanel.editor.doc.db.randomizeRectsPos(randRegion)
      self.blockPanel.editor.updateRatio()
      self.blockPanel.editor.invalidate()
  
  proc onButtonTest(self: wMainPanel) =
    if self.blockPanel != nil:
      for rect in self.blockPanel.editor.doc.db.values:
        echo &"id: {rect.id}, pos: {(rect.x, rect.y)}, size: {(rect.w, rect.h)}, rot: {rect.rot}"
  # Left  arrow = stack from left to right, which is x ascending
  # Right arrow = stack from right to left, which is x descending
  # Up    arrow = stack from top to bottom, which is y descending
  # Down  arrow = stack from bottom to top, which is y ascending
  proc onButtonCompact←(self: wMainPanel) =
    self.delegate1DButtonCompact(X, Ascending)
  proc onButtonCompact→(self: wMainPanel) =
    self.delegate1DButtonCompact(X, Descending)
  proc onButtonCompact↓(self: wMainPanel) =
    self.delegate1DButtonCompact(Y, Ascending)
  proc onButtonCompact↑(self: wMainPanel) =
    self.delegate1DButtonCompact(Y, Descending)
  proc onButtonCompact←↑(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, Ascending, Descending))
  proc onButtonCompact←↓(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, Ascending, Ascending))
  proc onButtonCompact→↑(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, Descending, Descending))
  proc onButtonCompact→↓(self: wMainPanel) =
    self.delegate2DButtonCompact((X, Y, Descending, Ascending))
  proc onButtonCompact↑←(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, Descending, Ascending))
  proc onButtonCompact↑→(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, Descending, Descending))
  proc onButtonCompact↓←(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, Ascending, Ascending))
  proc onButtonCompact↓→(self: wMainPanel) =
    self.delegate2DButtonCompact((Y, X, Ascending, Descending))

  var ackCnt: int
  proc onAlgUpdate(self: wMainPanel, event: wEvent) =
    let (idx, _) = paramSplit(event.lParam)
    let (msgAvail, msg) = gAnnealComms[idx].sendChan.tryRecv()
    if self.blockPanel != nil:
      if msgAvail:
          self.blockPanel.editor.text = $idx.int64 & ": " & msg 
    
    let (_, _) = gAnnealComms[idx].idChan.tryRecv()
    if self.blockPanel != nil:
      withLock(gLock):
        self.blockPanel.renderer.clearTextureCache()
        #self.blockPanel.forceRedraw(0)
        self.blockPanel.refresh(false)
        gAnnealComms[idx].ackChan.send(ackCnt)
      inc ackCnt

  proc init*(self: wMainPanel, parent: wWindow) =
    when defined(debug):
      echo "mainpanel init"
    wPanel(self).init(parent)

    let rectQty = gAppOpts.compQty

    # Create controls
    self.txt       = StaticText(self, label="Qty", style=wSpRight)
    self.spnr      = SpinCtrl(self, id=wCommandID(1), value=rectQty, style=wAlignRight)
    self.box1      = StaticBox(self, label="Strat and func")
    self.ctrb1     = RadioButton(self, label="None", style=wRbGroup)
    self.ctrb2     = RadioButton(self, label="Anneal")
    self.ctrb3     = RadioButton(self, label="Stack" )
    self.aStratRb1 = RadioButton(self, label="Strat1", style=wRbGroup)
    self.aStratRb2 = RadioButton(self, label="Strat2")
    self.aStratRb3 = RadioButton(self, label="Wiggle", style=wRbGroup)
    self.aStratRb4 = RadioButton(self, label="Swap"  )

    self.slider  = Slider(self)
    self.buttons[ 0] = Button(self, label = "randomize All"     )
    self.buttons[ 1] = Button(self, label = "randomize Pos"     )
    self.buttons[ 2] = Button(self, label = "Test"              )
    self.buttons[ 3] = Button(self, label = "Compact X←"        )
    self.buttons[ 4] = Button(self, label = "Compact X→"        )
    self.buttons[ 5] = Button(self, label = "Compact Y↑"        )
    self.buttons[ 6] = Button(self, label = "Compact Y↓"        )
    self.buttons[ 7] = Button(self, label = "Compact X← then Y↑")
    self.buttons[ 8] = Button(self, label = "Compact X← then Y↓")
    self.buttons[ 9] = Button(self, label = "Compact X→ then Y↑")
    self.buttons[10] = Button(self, label = "Compact X→ then Y↓")
    self.buttons[11] = Button(self, label = "Compact Y↑ then X←")
    self.buttons[12] = Button(self, label = "Compact Y↑ then X→")
    self.buttons[13] = Button(self, label = "Compact Y↓ then X←")
    self.buttons[14] = Button(self, label = "Compact Y↓ then X→")
    self.buttons[15] = Button(self, label = "Save"              )
    self.buttons[16] = Button(self, label = "Load"              )

    # Connect events
    self.wEvent_Size                do (event: wEvent): self.onResize(event)
    self.spnr.wEvent_Spin          do (event: wEvent): self.onSpinSpin(event)
    self.spnr.wEvent_TextEnter     do (): self.onSpinTextEnter()
    self.ctrb1.wEvent_RadioButton  do (event: wEvent): self.onStrategyRadioButton(event)
    self.ctrb2.wEvent_RadioButton  do (event: wEvent): self.onStrategyRadioButton(event)
    self.ctrb3.wEvent_RadioButton  do (event: wEvent): self.onStrategyRadioButton(event)
    self.slider.wEvent_Slider        do (event: wEvent): self.onSlider(event)
    self.buttons[ 0].wEvent_Button do (): self.onButtonrandomizeAll()
    self.buttons[ 1].wEvent_Button do (): self.onButtonrandomizePos()
    self.buttons[ 2].wEvent_Button do (): self.onButtonTest()
    self.buttons[ 3].wEvent_Button do (): self.onButtonCompact←()
    self.buttons[ 4].wEvent_Button do (): self.onButtonCompact→()
    self.buttons[ 5].wEvent_Button do (): self.onButtonCompact↑()
    self.buttons[ 6].wEvent_Button do (): self.onButtonCompact↓()
    self.buttons[ 7].wEvent_Button do (): self.onButtonCompact←↑()
    self.buttons[ 8].wEvent_Button do (): self.onButtonCompact←↓()
    self.buttons[ 9].wEvent_Button do (): self.onButtonCompact→↑()
    self.buttons[10].wEvent_Button do (): self.onButtonCompact→↓()
    self.buttons[11].wEvent_Button do (): self.onButtonCompact↑←()
    self.buttons[12].wEvent_Button do (): self.onButtonCompact↑→()
    self.buttons[13].wEvent_Button do (): self.onButtonCompact↓←()
    self.buttons[14].wEvent_Button do (): self.onButtonCompact↓→()
    self.idMsgAlgUpdate            do (event: wEvent): self.onAlgUpdate(event)

    # # Set up stuff
    self.blockPanel = BlockPanel(self)
    self.spnr.setRange(1, 10000)
    self.slider.setValue(20)
    self.ctrb1.click()
    self.aStratRb1.click()
    self.aStratRb3.click()

