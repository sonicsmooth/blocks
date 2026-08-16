import std/[strformat, 
            math,
            options,
            tables
            ]
#import std/[monotimes, times]
export tables

import wNim/wTypes
import sdl2 except Color

import appopts
import background
import colors
import sdlcolors
import common
import document
import editor
import pixiecomponents
import rects
import reporting
import rotation
import sdlcomponents
import sdlcommon
import viewport

export document, editor, sdl2

type
  CacheKey = tuple[id:CompID, hovering, selected: bool, rect: Option[PRect]]
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


when defined(profile):
  var
    gCumtime: Duration


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

proc clampSize(self: Renderer, pxSz: PxSize): PxSize =
  # Return the given prect if one or more of its dimensions fits in client area
  # If both dimensions exceed client size, then return a PRect with the
  # same aspect ratio and with one dim that matches client dim.
  # Used for extreme zoom where the component is bigger than the viewing area
  let clientSize: PxSize = self.editor.viewport.clientSize
  if pxSz.w <= clientSize.w or pxSz.h <= clientSize.h:
    pxSz
  else:
    let 
      rectRatio: float = pxSz.w.float / pxSz.h.float
      clientRatio: float = clientSize.w / clientSize.h
    var neww, newh: int
    if rectRatio <= clientRatio:
      # Set rect width to client width
      neww = clientSize.w
      newh = (neww.float / rectRatio).round.int
    else:
      # Set rect height to client height
      newh = clientSize.h
      neww = (newh.float * rectRatio).round.int
    (neww, newh)

# proc clampRect(self: Renderer, prect: PRect): PRect = 
#   let newsz: PxSize = self.clampSize((prect.w, prect.h))
#   (prect.x, prect.y, newsz.w, newsz.h)



#[ Component rendering options:
  1. Default renderer -> rp.drawRect
  2. Software renderer -> rp.drawRect -> cache -> blit
  3. Texture as rendering target -> rp.drawRect -> cache -> blit
  4. Pixie.Image, then update texture cache, then blit to sdlRenderer 
  5. Lock texture then draw with pixie, then unlock and blit to sdlRenderer ]# 


proc clearTextureCache*(self: Renderer) =
  # Clear all textures
  for texture in self.textureCache.values:
    texture.destroy()
  self.textureCache.clear()
  when defined(profile):
    gCumtime = initDuration()

proc clearTextureCache(self: Renderer, id: CompID) =
  # Clear all texture cache entries for a specific component id
  var toRemove: seq[CacheKey]
  for k in self.textureCache.keys:
    if k.id == id:
      toRemove.add(k)
  for k in toRemove:
    self.textureCache[k].destroy()
    self.textureCache.del(k)

proc syncTextureCache*(self: Renderer) =
  # Clear texture for dirty items
  for id in self.editor.dirty[].items: #.trueItems:
    self.clearTextureCache(id)
  self.editor.dirty.clearAll()

proc clearFontCaches*(self: Renderer) =
  clearTypefaceCache()
  clearFontCache()

proc screenRectP(self: Renderer): PRect =
  let sz = self.editor.viewport.clientSize
  (0.PxType, 0.PxType, sz.w, sz.h)

proc buildTexture(self: Renderer, comp: DBComp, rmethod: RenderMethod, 
                  isect: PRect, hov, sel: bool): TexturePtr = 
  let vp = self.editor.viewport
  let texSz = case comp.rot
              of R0, R180: pxSize(isect.w, isect.h)
              else: pxSize(isect.h, isect.w)
  let texRect: PRect = (0, 0, texSz.w, texSz.h)
  let fullRect: PRect = comp.pbbox(vp)
  echo fullRect, " -> ", texRect
  case rmethod
  of SDLTexture:
    result = self.sdlRenderer.createTexture(SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_TARGET, texSz.w, texSz.h)
    result.setTextureBlendMode(BlendMode_Blend)
    self.sdlRenderer.setRenderTarget(result)
    self.sdlRenderer.setDrawColor(0, 0, 0, 0)
    self.sdlRenderer.clear()
    self.sdlRenderer.renderDBCompSDL(comp, texRect, vp, hov, sel, false)
    self.sdlRenderer.setRenderTarget(nil)
  of PixieTexture:
    let image = renderDBCompPixie(comp, texSz, vp.zoom, hov, sel)
    let surface = createRGBSurfaceFrom(image.data[0].addr, texSz.w, texSz.h, 
                                32, texSz.w * 4, amask, bmask, gmask, rmask)
    sdlFailIf(surface.isNil): "Create surface failed"
    result = self.sdlRenderer.createTextureFromSurface(surface)
    sdlFailIf(result.isNil): "CreateTextureFromSurface failed"
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
    let hov = self.editor.isHovering(comp.id)
    let sel = self.editor.isSelected(comp.id)
    if rmethod == SDLDirect:
      self.sdlRenderer.renderDBCompSDL(comp, pbb, vp, hov, sel, true)
    else:
      #let csz = self.editor.viewport.clientSize
      let clientRect = self.editor.viewport.clientRect
      let isect = intersect(clientRect, pbb)
      #if isect.w == 0 or isect.h == 0: raise newException(RangeDefect, "Component out of bounds")
      let key = if comp.id in self.editor.fat[]:
                  (comp.id, hov, sel, some(isect))
                else:
                  (comp.id, hov, sel, none(PRect))
      if key notin self.textureCache:
        self.textureCache[key] = self.buildTexture(comp, rmethod, isect, hov, sel)  
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
  if gAppOpts.showScale:
    self.sdlRenderer.drawScale(vp, grid, font(defFontSize) )
  self.drawSelectBox()

  self.sdlRenderer.present()
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
