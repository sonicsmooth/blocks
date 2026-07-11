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

proc init*(app: var Application, w, h: int) =
  # Create stuff
  app.wapp = wApp.App()
  echo "init before mainframe"
  app.mainFrame = MainFrame((w, h))
  echo "init after mainframe"
  app.doc = newDocument()
  app.editor = newEditor(app.doc.grid.mZctrl)
  app.renderer = newRenderer()

  # Assign stuff
  app.mainFrame.editor = app.editor
  app.mainFrame.doc = app.doc
  app.editor.doc = app.doc
  app.renderer.doc = app.doc
  app.renderer.editor = app.editor

  # The block panel needs to point stuff
  app.mainFrame.mainPanel.blockPanel.renderer = app.renderer
  app.mainFrame.mainPanel.blockPanel.editor = app.editor
  echo "app editor: ", $cast[int](app.editor)
  echo "app editorx2: ", $cast[int](app.mainFrame.mainPanel.blockPanel.editor)

  # But the renderer class needs to point to some low level stuff
  # that is created when the panel is created
  app.renderer.sdlRenderer = app.mainFrame.mainPanel.blockPanel.sdlRenderer
  app.renderer.sdlWindow   = app.mainFrame.mainPanel.blockPanel.sdlWindow

  # Editor needs to be able to invalidate panel without knowing about panel
  #!app.editor.invalidate = proc() {.closure.} = app.mainFrame.mainPanel.blockPanel.refresh(false)


proc go*(app: Application) =
  app.mainFrame.center()
  app.mainFrame.show()
  app.wapp.mainLoop()