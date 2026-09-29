import std/[strformat,
            options,
            tables]
when defined(monotimeProfile):
  import std/[monotimes, times]
export tables

import appopts
import colors
import common
import document
import editor
import pubsub
import rects
import reporting
import rotation
import viewport
import world

import sdl2 except Color
import background
import sdlcolors
import pixiecomponents
import sdlcomponents
import sdlcommon

export document, editor, sdl2


# TODO: fat+rotated components can render incorrectly or disappear.
# The crop-to-screen logic assumes canonical (unrotated) space derivable
# from a simple w/h swap, which only holds when isect == the full pbb.
# Needs proper local-space cropping (inverse-rotate screen crop into
# component space) -- deferred until origin-at-(0,0) refactor + arbitrary
# rotation land, since this will be rebuilt on that foundation anyway.

type
  CacheKey = tuple[id:CompID, hovering, selected: bool, rect: Option[PxRect]]
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

proc clearTextureCache*(self: Renderer)
proc init*(self: Renderer) =
  self.backgroundColor = MintCream
  psAddListener(QtyChanged, proc(_: int) = self.clearTextureCache())


proc isReady*(self: Renderer): bool =
  if self.doc.isNil: return reportNil("renderer.doc")
  if self.editor.isNil: return reportNil("renderer.editor")
  if self.sdlRenderer.isNil: return reportNil("renderer.sdlRenderer")
  if self.sdlWindow.isNil: return reportNil("renderer.sdlWindow")
  if not self.doc.isReady(): return reportNotReady("renderer.doc")
  if not self.editor.isReady(): return reportNotReady("renderer.editor")
  true

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
  for id in self.editor.dirty[].items:
    self.clearTextureCache(id)
  self.editor.dirty.clearAll()

proc clearFontCaches*(self: Renderer) =
  clearTypefaceCache()
  clearFontCache()

proc screenRectP(self: Renderer): PxRect =
  let sz = self.editor.viewport.clientSize
  (0.toPxType, 0.toPxType, sz.w, sz.h)

proc buildTexture(self: Renderer, comp: DBComp, rmethod: RenderMethod,
                  isect: PxRect, hov, sel: bool): TexturePtr =
  let vp = self.editor.viewport
  let texSz = case comp.rot
              of R0, R180: pxSize(isect.w, isect.h)
              else: pxSize(isect.h, isect.w)
  let texRect: PxRect = (0, 0, texSz.w, texSz.h)
  case rmethod
  of SDLTexture:
    result = self.sdlRenderer.createTexture(SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_TARGET, texSz.w, texSz.h)
    result.setTextureBlendMode(BlendMode_Blend)
    self.sdlRenderer.setRenderTarget(result)
    self.sdlRenderer.renderDBCompSDL(comp, texRect, vp, hov, sel, false)
    self.sdlRenderer.setRenderTarget(nil)
  of PixieTexture:
    let image = renderDBCompPixie(comp, texSz, vp.zoom, hov, sel)
    let surface = createRGBSurfaceFrom(addr image.data[0], texSz.w, texSz.h,
                                32, texSz.w * 4, amask, bmask, gmask, rmask)
    sdlFailIf(surface.isNil): "Create surface failed"
    result = self.sdlRenderer.createTextureFromSurface(surface)
    sdlFailIf(result.isNil): "CreateTextureFromSurface failed"
    surface.destroy()
  of PixieLock:
    raise newException(ValueError, "PixieLock rendering not yet implemented")
  else:
    raise newException(ValueError, &"Unsupported cached render method: {rmethod}")

proc drawCachedTexture(self: Renderer, comp: DBComp, texture: TexturePtr, vp: Viewport, dstRect: PxRect) =
  let pivot = comp.rotationPoint(vp)
  self.sdlRenderer.copyEx(texture, nil, addr dstRect, -comp.rot.toFloat, addr pivot)

proc renderDBComps(self: Renderer, rmethod: RenderMethod) =
  self.visibleComponents.setLen(0)
  let vp = self.editor.viewport
  for comp in self.doc.db.values:
    let pbb = comp.pbbox(vp) # rotated
    if isRectSeparate(pbb, self.screenRectP): continue
    # Not really needed since we limit texture size
    if isRectTooBig(pbb, 16384): continue
    let hov = self.editor.isCompHovering(comp.id)
    let sel = self.editor.isCompSelected(comp.id)
    if rmethod == SDLDirect:
      self.sdlRenderer.renderDBCompSDL(comp, pbb, vp, hov, sel, true)
    else:
      let
        isFat = comp.id in self.editor.fat[]
        buildRect = if isFat: intersect(self.editor.viewport.clientRect, pbb) else: pbb
        key = if isFat: (comp.id, hov, sel, some(buildRect))
              else:     (comp.id, hov, sel, none(PxRect))
      if key notin self.textureCache:
        self.textureCache[key] = self.buildTexture(comp, rmethod, buildRect, hov, sel)
      let dstRect = if isFat: buildRect else: comp.localPRect(vp)
      self.drawCachedTexture(comp, self.textureCache[key], vp, dstRect)
    self.visibleComponents.add(comp)

proc drawSelectBox(self: Renderer) =
  if self.editor.selectBox.w == 0 or
     self.editor.selectBox.h == 0:
      return
  let fillColor = ColorRGBA(r: 0, g:102, b: 204, a:70)
  let penColor = ColorRGBA(r: 0, g:120, b: 215, a:255)
  self.sdlRenderer.drawFilledOutlineRectSDL(self.editor.selectBox, fillColor, penColor)

proc drawPlacementBox(self: Renderer) =
  if self.editor.dstRect.rect.w == 0 or
     self.editor.dstRect.rect.h == 0:
      return
  let fillColor = DarkOrchid.setAlpha(10)
  let penColor = DarkOrchid
  let dstRectP = self.editor.dstRect.rect.toPxRect(self.editor.viewport)
  
  # Main body rectangle
  let (x,y,w,h) = dstRectP
  self.sdlRenderer.drawFilledOutlineRectSDL(dstRectP, fillColor, penColor)

  # Corner boxes
  let cmarg = self.editor.dstRect.selCornerMargin
  let tlDstRectP: PxRect = (x,         y,         cmarg, cmarg)
  let trDstRectP: PxRect = (x+w-cmarg, y,         cmarg, cmarg)
  let blDstRectP: PxRect = (x,         y+h-cmarg, cmarg, cmarg)
  let brDstRectP: PxRect = (x+w-cmarg, y+h-cmarg, cmarg, cmarg)
  self.sdlRenderer.drawFilledOutlineRectSDL(tlDstRectP, fillColor, penColor)
  self.sdlRenderer.drawFilledOutlineRectSDL(trDstRectP, fillColor, penColor)
  self.sdlRenderer.drawFilledOutlineRectSDL(blDstRectP, fillColor, penColor)
  self.sdlRenderer.drawFilledOutlineRectSDL(brDstRectP, fillColor, penColor)

  # Edge highlight
  let hk = self.editor.dstRect.hoverKind
  case hk:
  of hkLeftEdge:
    self.sdlRenderer.drawLine(x+1, y, x+1, y+h)
    self.sdlRenderer.drawLine(x+2, y, x+2, y+h)
  of hkRightEdge:
    self.sdlRenderer.drawLine(x+w-2, y, x+w-2, y+h)
    self.sdlRenderer.drawLine(x+w-3, y, x+w-3, y+h)
  of hkTopEdge:
    self.sdlRenderer.drawLine(x, y+1, x+w, y+1)
    self.sdlRenderer.drawLine(x, y+2, x+w, y+2)
  of hkBottomEdge:
    self.sdlRenderer.drawLine(x, y+h-2, x+w, y+h-2)
    self.sdlRenderer.drawLine(x, y+h-3, x+w, y+h-3)

  # Corner highlight
  of hkTLCorner:
    self.sdlRenderer.drawFilledOutlineRectSDL(tlDstRectP.shrink(1), fillColor, penColor)
    self.sdlRenderer.drawFilledOutlineRectSDL(tlDstRectP.shrink(2), fillColor, penColor)
  of hkTRCorner:
    self.sdlRenderer.drawFilledOutlineRectSDL(trDstRectP.shrink(1), fillColor, penColor)
    self.sdlRenderer.drawFilledOutlineRectSDL(trDstRectP.shrink(2), fillColor, penColor)
  of hkBLCorner:
    self.sdlRenderer.drawFilledOutlineRectSDL(blDstRectP.shrink(1), fillColor, penColor)
    self.sdlRenderer.drawFilledOutlineRectSDL(blDstRectP.shrink(2), fillColor, penColor)
  of hkBRCorner:
    self.sdlRenderer.drawFilledOutlineRectSDL(brDstRectP.shrink(1), fillColor, penColor)
    self.sdlRenderer.drawFilledOutlineRectSDL(brDstRectP.shrink(2), fillColor, penColor)
  of hkBody, hkChild, hkNone:
    discard

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

  # Draw various boxes and text, then done
  #self.updateDestinationBox()
  #if gAppOpts.enableDstRect:
  if self.editor.checkPLF():
    self.drawPlacementBox()
  # if gAppOpts.enableBbox:
  #   #self.updateBoundingBox()
  #   self.sdlRenderer.drawOutlineRectSDL(self.editor.allBbox.toPxRect(self.editor.viewport).grow(1), Green)
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
  self.sdlRenderer.present()

  # release(gLock)
