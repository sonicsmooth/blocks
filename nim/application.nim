import wNim/[wApp, wWindow]
import document, editor, renderer, mainframe
import sdlframes

type
  Application* = object
    wapp: wApp
    doc: Document
    editor: Editor
    renderer: Renderer
    mainFrame: wMainFrame

proc init*(app: var Application, w,h: int) =
  # Create stuff
  app.wapp = App()
  app.mainFrame = MainFrame((w, h))
  app.doc = newDocument()
  app.editor = newEditor()
  app.renderer = newRenderer()
  initSDL()

  # Assign stuff
  app.editor.doc = app.doc
  app.renderer.doc = app.doc
  app.renderer.editor = app.editor

  # The block panel needs to point to the renderer class
  # so panel can call renderer from OnPaint
  app.mainFrame.mainPanel.blockPanel.renderer = app.renderer

  # But the renderer class needs to point to some low level stuff
  # that is created when the panel is created
  app.renderer.sdlRenderer = app.mainFrame.mainPanel.blockPanel.sdlRenderer
  app.renderer.sdlWindow   = app.mainFrame.mainPanel.blockPanel.sdlWindow
  app.renderer.backgroundColor = app.mainFrame.mainPanel.blockPanel.backgroundColor.toColor

  # Editor needs to be able to invalidate panel without knowing about panel
  #!app.editor.invalidate = proc() {.closure.} = app.mainFrame.mainPanel.blockPanel.refresh(false)



proc go*(app: Application) =
  app.mainFrame.center()
  app.mainFrame.show()
  app.wapp.mainLoop()