import std/[random]
import wNim/[wApp, wWindow, wUtils]
import wNim/[wSlider, wStatusBar]

import appopts
import anneal
import concurrent
import document
import editor
import mainframe
import renderer
import reporting
import sdlframes

export document, editor, renderer

type
  Application* = ref object
    wapp: wApp
    doc: Document
    editor: Editor
    renderer: Renderer
    mainFrame: wMainFrame

proc newApplication*(): Application =
  new Application

proc isReady*(self: Application): bool =
  if self.doc.isNil: return reportNil("app.doc")
  if self.editor.isNil: return reportNil("app.editor")
  if self.renderer.isNil: return reportNil("app.renderer")
  if self.mainFrame.isNil: return reportNil("app.mainFrame")
  if not self.doc.isReady(): return reportNotReady("app.doc")
  if not self.editor.isReady(): return reportNotReady("app.editor")
  if not self.renderer.isReady(): return reportNotReady("app.renderer")
  if not self.mainFrame.isReady(): return reportNotReady("app.mainFrame")
  true

proc init*(self: Application, w, h: int) =
  # Start things up.  Assume command line args have already been
  # parsed and are in gAppOpts

  # Generic system stuff
  randomize()
  wSetSystemDpiAware()
  when defined(debug):
    echo "DPI: ", wAppGetDpi()
  concurrent.init()
  anneal.init()

  # Create stuff
  self.wapp = wApp.App()
  self.mainFrame = MainFrame((w, h), barebones=false)
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
  self.renderer.init()

  # Set up initial values of UI elements
  if self.mainFrame.isReady():
    let sldrVal = self.mainFrame.mainPanel.slider.value
    let tmpStr = "temperature: " & $sldrVal
    self.mainframe.mStatusBar.setStatusText(tmpStr, index=0)

  # Initialize data
  self.mainFrame.mainPanel.randomizeRectsAll()

  self.mainFrame.invalidate = proc() =
    self.renderer.clearTextureCache()
    self.renderer.clearFontCaches()

  self.editor.onZoomChanged = proc() {.closure.} =
    if gAppOpts.retextureAllOnZoom:
      # Redo all the textures for nice images
      self.renderer.clearTextureCache()

  # Editor needs to be able to invalidate panel without knowing about panel
  # refresh has been moved to timer
  self.editor.invalidate = proc() {.closure.} = 
    if gAppOpts.retextureFatOnMove:
      # For every move, we redo the textures that are
      # too big to fit on the screen
      self.editor.dirtifyFatComponents()
    self.renderer.syncTextureCache()
    #self.mainFrame.mainPanel.blockPanel.refresh(false)

proc deinit*(app: Application) = 
  # Shut down
  concurrent.deinit()
  anneal.deinit()


proc go*(app: Application) =
  app.mainFrame.center()
  app.mainFrame.show()
  app.wapp.mainLoop()