import wNim/[wApp, wWindow]
import wNim/[wSlider, wStatusBar]
import document, editor, renderer, mainframe
import reporting
import sdlframes

type
  Application* = object
    wapp: wApp
    doc: Document
    editor: Editor
    renderer: Renderer
    mainFrame: wMainFrame

proc isReady*(self: Application): bool =
  #if self.wapp.isNil: return reportNil(app.wapp)
  if self.doc.isNil: return reportNil("app.doc")
  if self.editor.isNil: return reportNil("app.editor")
  if self.renderer.isNil: return reportNil("app.renderer")
  if self.mainFrame.isNil: return reportNil("app.mainFrame")
  if not self.doc.isReady(): return reportNotReady("app.doc")
  if not self.editor.isReady(): return reportNotReady("app.editor")
  if not self.renderer.isReady(): return reportNotReady("app.renderer")
  if not self.mainFrame.isReady(): return reportNotReady("app.mainFrame")
  true

proc init*(self: var Application, w, h: int) =
  # Create stuff
  self.wapp = wApp.App()
  self.mainFrame = MainFrame((w, h))
  self.doc = newDocument()
  self.editor = newEditor(self.doc.grid.mZctrl)
  self.renderer = newRenderer()

  # Assign stuff
  self.mainFrame.editor = self.editor
  self.mainFrame.doc    = self.doc
  self.editor.doc       = self.doc
  self.renderer.doc     = self.doc
  self.renderer.editor  = self.editor

  # The block panel needs to point to stuff
  self.mainFrame.mainPanel.blockPanel.renderer = self.renderer
  self.mainFrame.mainPanel.blockPanel.editor =  self.editor

  # But the renderer class needs to point to some low level stuff
  # that is created when the panel is created
  self.renderer.sdlRenderer = self.mainFrame.mainPanel.blockPanel.sdlRenderer
  self.renderer.sdlWindow   = self.mainFrame.mainPanel.blockPanel.sdlWindow

  # Set up initial values of UI elements
  if self.mainFrame.isReady():
    let sldrVal = self.mainFrame.mainPanel.slider.value
    let tmpStr = "temperature: " & $sldrVal
    self.mainframe.mStatusBar.setStatusText(tmpStr, index=0)

  # Initialize data
  self.mainFrame.mainPanel.randomizeRectsAll()

  # Editor needs to be able to invalidate panel without knowing about panel
  #!app.editor.invalidate = proc() {.closure.} = app.mainFrame.mainPanel.blockPanel.refresh(false)

proc go*(app: Application) =
  app.mainFrame.center()
  app.mainFrame.show()
  app.wapp.mainLoop()