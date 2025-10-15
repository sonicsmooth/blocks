import std/[algorithm, locks, math, segfaults, sets, strformat, tables ]
from std/sequtils import toSeq, foldl
import wNim
import winim
import anneal, appopts, compact, concurrent, db
import stack, userMessages, utils, blockpanel, world
export blockpanel

type
  wMainPanel* = ref object of wPanel
    mBlockPanel*: wBlockPanel
    mSpnr: wSpinCtrl
    mTxt:  wStaticText
    mChk:  wCheckBox
    mBox1: wStaticBox
    #mBox2: wStaticBox
    mCTRb1:     wRadioButton # Compact type radio button
    mCTRb2:     wRadioButton # Compact type radio button
    mCTRb3:     wRadioButton # Compact type radio button
    mAStratRb1: wRadioButton # Anneal strategy radio button
    mAStratRb2: wRadioButton # Anneal strategy radio button
    mAStratRb3: wRadioButton # Anneal strategy radio button
    mAStratRb4: wRadioButton # Anneal strategy radio button
    mSldr*: wSlider
    mButtons: array[17, wButton]

const 
  logRandomize = true
  randRegion: WRect = (-400, -400, 801, 801)


wClass(wMainPanel of wPanel):
  proc layout(self: wMainPanel) =
    let 
      bmarg = self.dpiScale(8)
      (cszw, cszh) = self.clientSize
      (bw, bh) = (self.dpiScale(150), self.dpiScale(30))
      (lbpmarg, rbpmarg, tbpmarg, bbpmarg) = (0, 8, 0, 0)
      bwd2 = bw div 2
    self.mBlockPanel.position = (bw + 2*bmarg + lbpmarg, tbpmarg)
    self.mBlockPanel.size = (cszw - bw - 2*bmarg - lbpmarg - rbpmarg, 
                             cszh - tbpmarg - bbpmarg)
    var yPosAcc = 0
    # Static text position, size
    self.mTxt.position = (bmarg, bmarg)
    self.mTxt.size = (bwd2, self.mTxt.size.height)

    # Spin Ctrl position, size
    self.mSpnr.position = (bmarg + bwd2, bmarg)
    self.mSpnr.size     = (bwd2, self.mSpnr.size.height)
    yPosAcc += bmarg + self.mTxt.size.height

    # Selection strategy pos, size
    self.mCTRb1.position = (bmarg,            yPosAcc); yPosAcc += bh
    self.mCTRb2.position = (bmarg,            yPosAcc)
    self.mCTRb3.position = (bmarg + bwd2, yPosAcc)

    self.mCTRb1.size     = (bw,       bh)
    self.mCTRb2.size     = (bwd2, bh)
    self.mCTRb3.size     = (bwd2, bh)
    yPosAcc += bmarg + bh

    # Slider position, size
    self.mSldr.position = (bmarg, yPosAcc)
    self.mSldr.size    = (bw, bh)
    yPosAcc += bmarg + bh

    # Static box1 and radio button position, size
    self.mBox1.position      = (bmarg,   yPosAcc          )
    self.mAStratRb1.size = (bwd2, bh)
    self.mAStratRb2.size = (bwd2, bh)
    self.mAStratRb3.size = (bwd2, bh)
    self.mAStratRb4.size = (bwd2, bh)
    self.mAStratRb1.position = (bmarg*2, yPosAcc + bmarg*3); #yPosAcc += self.mAStratRb1.size.height
    self.mAStratRb3.position = (bmarg*2+bwd2, yPosAcc + bmarg*3); yPosAcc += self.mAStratRb3.size.height
    self.mAStratRb2.position = (bmarg*2, yPosAcc + bmarg*3); #yPosAcc += self.mAStratRb2.size.height
    self.mAStratRb4.position = (bmarg*2+bwd2, yPosAcc + bmarg*3); yPosAcc += self.mAStratRb4.size.height
    self.mBox1.size = (bw, self.mAStratRb1.size.height*2 + bmarg*4)
    yPosAcc += bmarg*5

    # Static box2 position, size
    #self.mBox2.position = (bmarg,   yPosAcc          )
    #self.mBox2.size = (bw, self.mAStratRb3.size.height*2 + bmarg*4)
    #yPosAcc += bmarg*5

    # Buttons position, size
    for i, butt in self.mButtons:
      butt.position = (bmarg, yPosAcc)
      butt.size     = (bw, bh)
      yPosAcc += bh

  proc randomizeRectsAll*(self: wMainPanel, qty: int=self.mSpnr.value) =
    gDb.randomizeRectsAll(randRegion, qty, logRandomize)
    self.mBlockPanel.mFillArea = gDb.fillArea()
    self.mBlockPanel.updateRatio()
    self.mBlockPanel.clearTextureCache()

  proc delegate1DButtonCompact(self: wMainPanel, axis: Axis, sortOrder: SortOrder) = 
    #echo GC_getStatistics()
    withLock(gLock):
      compact(gDb, axis, sortOrder, self.mBlockPanel.mDstRect)
    self.mBlockPanel.updateRatio()
    self.refresh(false)
    GC_fullCollect()

  proc delegate2DButtonCompact(self: wMainPanel, direction: CompactDir) =
    # Leave if we have any threads already running
    if gCompactThread.running: return
    for i in gAnnealComms.low .. gAnnealComms.high:
      if gAnnealComms[i].thread.running: return

    let dstRect = self.mBlockPanel.mDstRect
    
    if self.mCtrb1.value: # Not anneal, just normal 2d compact
      let arg: CompactArg = (pRectTable:  gDb.addr,
                             direction:   direction,
                             window:      self,
                             dstRect:     dstRect)
      gCompactThread.createThread(compactWorker, arg)
      gCompactThread.joinThread()
      self.mBlockPanel.updateRatio()
      self.refresh(false)
    
    elif self.mCTRb2.value: # Do anneal
      proc compactfn() {.closure.} = 
        iterCompact(gDb, direction, dstRect)
      let strat = if self.mAStratRb1.value: Strat1
                  else:                     Strat2
      let perturbFn = if self.mAStratRb3.value: makeWiggler[PosTable, ptr RectTable](dstRect)
                      else:                     makeSwapper[PosTable, ptr RectTable]()
      for i in gAnnealComms.low .. gAnnealComms.high:
        let arg: AnnealArg = (pRectTable: gDb.addr,
                              strategy:   strat,
                              initTemp:   self.mSldr.value.float,
                              perturbFn:  perturbFn,
                              compactFn:  compactfn,
                              window:     self,
                              dstRect:    dstRect,
                              comm:       gAnnealComms[i])
        # Weird, TODO: just do once
        gAnnealComms[i].thread.createThread(annealMain, arg)
        # TODO: figure out how to clearTextureCache when thread is done
        break
    
    elif self.mCTRb3.value: # Do stack
      withLock(gLock):
        stackCompact(gDb, dstRect, direction)
      self.mBlockPanel.clearTextureCache()
      self.mBlockPanel.updateRatio()
      self.refresh(false)


  proc onResize(self: wMainPanel) =
    self.layout()
  proc onSpinSpin(self: wMainPanel, event: wEvent) =
    let qty = event.getSpinPos() + event.getSpinDelta()
    self.randomizeRectsAll(qty)
    self.mBlockPanel.updateRatio()
    self.refresh(false)
  proc onSpinTextEnter(self: wMainPanel) =
    if self.mSpnr.value > 0:
      self.randomizeRectsAll(self.mSpnr.value)
      self.mBlockPanel.updateRatio()
      self.refresh(false)
  proc onStrategyRadioButton(self: wMainPanel, event: wEvent) =
    if self.mCTRb1.value: # No strategy
      self.mSldr.disable()
      self.mAStratRb1.disable()
      self.mAStratRb2.disable()
      self.mAStratRb3.disable()
      self.mAStratRb4.disable()
    elif self.mCTRb2.value: # Anneal strategy
      self.mSldr.enable()
      self.mAStratRb1.enable()
      self.mAStratRb2.enable()
      self.mAStratRb3.enable()
      self.mAStratRb4.enable()
    elif self.mCTRb3.value: # Stack strategy
      self.mSldr.disable()
      self.mAStratRb1.disable()
      self.mAStratRb2.disable()
      self.mAStratRb3.disable()
      self.mAStratRb4.disable()

  proc onSlider(self: wMainPanel, event: wEvent) =
    let pos = event.scrollPos
    let hWnd = GetAncestor(self.handle, GA_ROOT)
    SendMessage(hwnd, USER_SLIDER, pos, pos)
  proc onButtonrandomizeAll(self: wMainPanel) =
    self.randomizeRectsAll(self.mSpnr.value)
    self.mBlockPanel.updateRatio()
    self.refresh(false)
  proc onButtonrandomizePos(self: wMainPanel) =
    #let sz = self.mBlockPanel.clientSize
    gDb.randomizeRectsPos(randRegion)
    self.mBlockPanel.updateRatio()
    self.refresh(false)
  proc onButtonTest(self: wMainPanel) =
    for rect in gDb.values:
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
    if msgAvail:
        self.mBlockPanel.mText = $idx.int64 & ": " & msg 
    
    let (_, _) = gAnnealComms[idx].idChan.tryRecv()
    withLock(gLock):
      self.mBlockPanel.clearTextureCache()
      self.mBlockPanel.forceRedraw(0)
      gAnnealComms[idx].ackChan.send(ackCnt)
    inc ackCnt

  proc init*(self: wMainPanel, parent: wWindow) =
    wPanel(self).init(parent)

    let rectQty = gAppOpts.compQty

    # Create controls
    self.mSpnr      = SpinCtrl(self, id=wCommandID(1), value=rectQty, style=wAlignRight)
    self.mTxt       = StaticText(self, label="Qty", style=wSpRight)
    self.mBox1      = StaticBox(self, label="Strat and func")
    #self.mBox2      = StaticBox(self, label="Anneal Perturb Func")
    self.mCTRb1     = RadioButton(self, label="None", style=wRbGroup)
    self.mCTRb2     = RadioButton(self, label="Anneal")
    self.mCTRb3     = RadioButton(self, label="Stack" )
    self.mAStratRb1 = RadioButton(self, label="Strat1", style=wRbGroup)
    self.mAStratRb2 = RadioButton(self, label="Strat2")
    self.mAStratRb3 = RadioButton(self, label="Wiggle", style=wRbGroup)
    self.mAStratRb4 = RadioButton(self, label="Swap"  )

    self.mSldr  = Slider(self)
    self.mButtons[ 0] = Button(self, label = "randomize All"     )
    self.mButtons[ 1] = Button(self, label = "randomize Pos"     )
    self.mButtons[ 2] = Button(self, label = "Test"              )
    self.mButtons[ 3] = Button(self, label = "Compact X←"        )
    self.mButtons[ 4] = Button(self, label = "Compact X→"        )
    self.mButtons[ 5] = Button(self, label = "Compact Y↑"        )
    self.mButtons[ 6] = Button(self, label = "Compact Y↓"        )
    self.mButtons[ 7] = Button(self, label = "Compact X← then Y↑")
    self.mButtons[ 8] = Button(self, label = "Compact X← then Y↓")
    self.mButtons[ 9] = Button(self, label = "Compact X→ then Y↑")
    self.mButtons[10] = Button(self, label = "Compact X→ then Y↓")
    self.mButtons[11] = Button(self, label = "Compact Y↑ then X←")
    self.mButtons[12] = Button(self, label = "Compact Y↑ then X→")
    self.mButtons[13] = Button(self, label = "Compact Y↓ then X←")
    self.mButtons[14] = Button(self, label = "Compact Y↓ then X→")
    self.mButtons[15] = Button(self, label = "Save"              )
    self.mButtons[16] = Button(self, label = "Load"              )

    # Connect events
    self.wEvent_Size                    do (event: wEvent): self.onResize()
    self.mSpnr.wEvent_Spin              do (event: wEvent): self.onSpinSpin(event)
    self.mSpnr.wEvent_TextEnter         do (): self.onSpinTextEnter()
    self.mCTRb1.wEvent_RadioButton      do (event: wEvent): self.onStrategyRadioButton(event)
    self.mCTRb2.wEvent_RadioButton      do (event: wEvent): self.onStrategyRadioButton(event)
    self.mCTRb3.wEvent_RadioButton      do (event: wEvent): self.onStrategyRadioButton(event)
    self.mSldr.wEvent_Slider            do (event: wEvent): self.onSlider(event)
    self.mButtons[ 0].wEvent_Button     do (): self.onButtonrandomizeAll()
    self.mButtons[ 1].wEvent_Button     do (): self.onButtonrandomizePos()
    self.mButtons[ 2].wEvent_Button     do (): self.onButtonTest()
    self.mButtons[ 3].wEvent_Button     do (): self.onButtonCompact←()
    self.mButtons[ 4].wEvent_Button     do (): self.onButtonCompact→()
    self.mButtons[ 5].wEvent_Button     do (): self.onButtonCompact↑()
    self.mButtons[ 6].wEvent_Button     do (): self.onButtonCompact↓()
    self.mButtons[ 7].wEvent_Button     do (): self.onButtonCompact←↑()
    self.mButtons[ 8].wEvent_Button     do (): self.onButtonCompact←↓()
    self.mButtons[ 9].wEvent_Button     do (): self.onButtonCompact→↑()
    self.mButtons[10].wEvent_Button     do (): self.onButtonCompact→↓()
    self.mButtons[11].wEvent_Button     do (): self.onButtonCompact↑←()
    self.mButtons[12].wEvent_Button     do (): self.onButtonCompact↑→()
    self.mButtons[13].wEvent_Button     do (): self.onButtonCompact↓←()
    self.mButtons[14].wEvent_Button     do (): self.onButtonCompact↓→()
    self.USER_ALG_UPDATE                do (event: wEvent): self.onAlgUpdate(event)

    # Set up stuff
    self.mBlockPanel = BlockPanel(self)
    self.mSpnr.setRange(1, 10000)
    self.mSldr.setValue(20)
    self.mCTRb1.click()
    self.mAStratRb1.click()
    self.mAStratRb3.click()

