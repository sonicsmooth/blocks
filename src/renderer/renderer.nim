import std/[sequtils,
            strutils, 
            strformat, 
            math,
            tables,
            ]
import wNim/wTypes
import sdl2 except Color
import sdl2/ttf

import appopts
import background
import colors, colors_sdl
import common
import document
import editor
import rects
import reporting
import rotation
import sdlComponents
import pixieComponents



type
  CacheKey = tuple[id:CompID, hovering, selected: bool]
  Renderer* = ref object of RootObj
    # Read-only domain data
    doc*: Document # For the design data
    editor*: Editor # For the decorations

    # Needed for drawing
    backgroundColor: ColorRGBA
    sdlRenderer*: RendererPtr
    sdlSoftwareRenderer: RendererPtr
    sdlWindow*: WindowPtr
    textureCache*: Table[CacheKey, TexturePtr] 
    visibleComponents*: seq[DBComp]



proc newRenderer*(): Renderer =
  result = new Renderer

proc init*(self: Renderer) =
  self.backgroundColor = MintCream

proc isReady*(self: Renderer): bool =
  if self.doc.isNil: return reportNil("renderer.doc")
  if self.editor.isNil: return reportNil("renderer.editor")
  if self.sdlRenderer.isNil: return reportNil("renderer.sdlRenderer")
  if self.sdlWindow.isNil: return reportNil("renderer.sdlWindow")
  if not self.doc.isReady(): return reportNotReady("renderer.doc")
  if not self.editor.isReady(): return reportNotReady("renderer.editor")
  true

proc clampRectSize(self: Renderer, prect: PRect): PRect =
  # Return the given prect if one or more of its dimensions fits in client area
  # If both dimensions exceed client size, then return a PRect with the
  # same aspect ratio and with one dim that matches client dim.
  # Used for extreme zoom where the component is bigger than the viewing area
  let sz: PxSize = self.editor.viewport.clientSize
  if prect.w <= sz.w or prect.h <= sz.h:
    prect
  else:
    let 
      rectRatio: float = prect.w.float / prect.h.float
      clientRatio: float = sz.w / sz.h
    var neww, newh: int
    if rectRatio <= clientRatio:
      # Set rect width to client width
      neww = self.editor.viewport.clientSize.w
      newh = (neww.float / rectRatio).round.int
    else:
      # Set rect height to client height
      newh = sz.h
      neww = (newh.float * rectRatio).round.int
    (x: prect.x, y: prect.y, w: neww, h: newh)



#[ Component rendering options:
  1. Default renderer -> rp.drawRect
  2. Software renderer -> rp.drawRect -> cache -> blit
  3. Texture as rendering target -> rp.drawRect -> cache -> blit
  4. Pixie.Image, then update texture cache, then blit to sdlRenderer 
  5. Lock texture then draw with pixie, then unlock and blit to sdlRenderer ]# 


# proc chooseRendererSDL(self: Renderer): RendererPtr =
#   if self.sdlSoftwareRenderer.isNil:
#     self.sdlRenderer
#   else:
#     self.sdlSoftwareRenderer

proc choosePRect(self: Renderer, comp: DBComp, rot: bool): PRect =
  # Rot true means return the real screen bounding box
  # Rot false means return zero-origin rectangle from unrotated comp
  if rot:
    comp.pbbox(self.editor.viewport)
  else:
    let psize = comp.pxSize(self.editor.viewport)
    (x: 0, y:0, w: psize.w, h: psize.h)

proc clearTextureCache*(self: Renderer) =
  # Clear all textures
  for texture in self.textureCache.values:
    texture.destroy()
  self.textureCache.clear()

proc clearTextureCache(self: Renderer, id: CompID) =
  # Clear specific id from texture cache
  for hov in [false, true]:
    for sel in [false, true]:
      let key = (id, hov, sel)
      if key in self.textureCache:
        self.textureCache[key].destroy()
      self.textureCache.del(key)

proc syncTextureCache*(self: Renderer) =
  for id in self.editor.dirty.trueItems:
    self.clearTextureCache(id)
  self.editor.dirty.clearAll()

proc screenRectP(self: Renderer): PRect =
  let sz = self.editor.viewport.clientSize
  (0.PxType, 0.PxType, sz.w, sz.h)

proc buildTexture(self: Renderer, comp: DBComp, rmethod: RenderMethod, 
                  hov, sel: bool): TexturePtr = 
  let texSz = comp.pxSize(self.editor.viewport)
  case rmethod
  of SDLTexture:
    let fmt = self.sdlWindow.getPixelFormat()
    result = self.sdlRenderer.createTexture(fmt, SDL_TEXTUREACCESS_TARGET, texSz.w, texSz.h)
    self.sdlRenderer.setRenderTarget(result)
    let prect = self.choosePRect(comp, false)
    self.sdlRenderer.renderDBCompSDL(comp, prect, self.editor.viewport, hov, sel, false)
    self.sdlRenderer.setRenderTarget(nil)
  of PixieTexture:
    let surface = renderDBCompPixie(comp, texSz, hov, sel)
    result = self.sdlRenderer.createTextureFromSurface(surface)
    if result.isNil:
      echo getError()
    surface.destroy()
  of PixieLock:
    raise newException(ValueError, "PixieLock rendering not yet implemented")
  else:
    raise newException(ValueError, &"Unsupported cached render method: {rmethod}")

proc drawCachedTexture(self: Renderer, comp: DBComp, texture: TexturePtr, vp: Viewport) =
  let
    tgtRect = comp.localPRect(vp)
    pivot = comp.rotationPoint(vp)
  self.sdlRenderer.copyEx(texture, nil, addr tgtRect, -comp.rot.toFloat, addr pivot)

proc renderDBComps(self: Renderer, rmethod: RenderMethod) =
  self.visibleComponents.setLen(0)
  let vp = self.editor.viewport
  for comp in self.doc.db.values:
    let pbb = comp.pbbox(vp) # rotated
    if isRectSeparate(pbb, self.screenRectP): continue
    let cprect = self.clampRectSize(pbb)
    if cprect.w == 0 or cprect.h == 0: continue
    let hov = self.editor.isHovering(comp.id)
    let sel = self.editor.isSelected(comp.id)
    if rmethod == SDLDirect:
      self.sdlRenderer.renderDBCompSDL(comp, cprect, vp, hov, sel, true)
    else:
      let key = (comp.id, hov, sel)
      if key notin self.textureCache:
        self.textureCache[key] = self.buildTexture(comp, rmethod, hov, sel)
      self.drawCachedTexture(comp, self.textureCache[key], vp)
    self.visibleComponents.add(comp)

proc drawSelectBox(self: Renderer) =
  if self.editor.selectBox.w == 0 or
     self.editor.selectBox.h == 0:
      return
  let fillColor = ColorRGBA(r: 0, g:102, b: 204, a:70)
  let penColor = ColorRGBA(r: 0, g:120, b: 215, a:255)
  self.sdlRenderer.drawFilledOutlineRectSDL(self.editor.selectBox, fillColor, penColor)


proc renderEverything*(self: Renderer) =
  # Typically called from OnPaint
  let 
    bg = self.backgroundColor
    vp = self.editor.viewport
    grid = self.doc.grid
  self.sdlRenderer.setDrawColor(bg)
  self.sdlRenderer.clear()
  self.sdlRenderer.drawGrid(vp, grid)
  self.renderDBComps(gAppOpts.renderMethod)
  self.sdlRenderer.drawScale(vp, grid, font(defFontSize) )
  self.drawSelectBox()

  # # Draw various boxes and text, then done
  # #self.updateDestinationBox()
  # if gAppOpts.enableDstRect:
  #   self.sdlRenderer.drawOutlineRectSDL(self.editor.texRect.toPRect(self.editor.viewport), DarkOrchid)
  # if gAppOpts.enableBbox:
  #   #self.updateBoundingBox()
  #   self.sdlRenderer.drawOutlineRectSDL(self.editor.allBbox.toPRect(self.editor.viewport).grow(1), Green)
  # txt &= &"pan: {self.editor.viewport.pan}\n"
  # txt &= &"zClicks: {self.editor.viewport.zClicks}\n"
  # txt &= &"level: {self.editor.viewport.zCtrl.logStep}\n"
  # txt &= &"rawZoom: {self.editor.viewport.rawZoom:.3f}\n"
  # txt &= &"zoom: {self.editor.viewport.zoom:.3f}\n"
  # txt &= &"smoothDelta: {minDelta(self.doc.grid, scale=None)}\n"
  # txt &= &"tinyDelta: {minDelta(self.doc.grid, scale=Tiny)}\n"
  # txt &= &"minorDelta: {minDelta(self.doc.grid, scale=Minor)}\n"
  # let majdelt = minDelta(self.doc.grid, scale=Major)
  # let pxwidth = (majdelt.x.float * self.editor.viewport.zoom).round.int
  # txt &= &"majorDelta: {majdelt}\n"
  # txt &= &"majorPx: {pxwidth}"
  
  # self.renderText(txt)
  # self.sdlRenderer.present()

  # release(gLock)
