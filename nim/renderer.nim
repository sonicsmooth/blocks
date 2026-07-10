import std/[enumerate,
            sequtils,
            strutils, 
            strformat, 
            tables, 
            math]
import wNim/wTypes
import sdl2
import sdl2/ttf
import document, grid, editor
import rects, utils, appopts
import shapes
from arange import arange



type
  CacheKey = tuple[id:CompID, selected, hovering: bool]
  Renderer* = ref object of RootObj
    # Read-only domain data
    doc*: Document # For the design data
    editor*: Editor # For the decorations

    # Needed for drawing
    backgroundColor*: Color
    sdlRenderer*: RendererPtr
    sdlWindow*: WindowPtr
    textureCache: Table[CacheKey, TexturePtr] 
    fontCache: Table[int, FontPtr]

const
  fontRange: Slice[int] = 6..100  
  fontScale = 0.45
  defFontSize = 25
  alphaOffset = 20
  stepAlphas = arange(60 .. 255, alphaOffset).toSeq

proc newRenderer*(): Renderer =
  result = new Renderer

proc isReady*(self: Renderer): bool =
  self.doc != nil and self.doc.isReady() and
  self.editor != nil and self.editor.isReady() and
  self.sdlRenderer != nil and
  self.sdlWindow != nil 

proc clientSize(self: Renderer): PxSize =
  var w, h: cint
  self.sdlRenderer.getLogicalSize(w, h)
  (w.PxType, h.Pxtype)

proc clampRectSize(self: Renderer, prect: PRect): PRect =
  # Return the given prect if one or more dimensions fits in client area
  # If both dimensions exceed client size, then return a PRect with the
  # same aspect ratio and with one dim that matches client dim.
  let sz: PxSize = self.clientSize #!! or self.editor.viewport.clientSize ?
  if prect.w <= sz.w or prect.h <= sz.h:
    prect
  else:
    let 
      rectRatio: float = prect.w.float / prect.h.float
      clientRatio: float = sz.w / sz.h
    var neww, newh: int
    if rectRatio <= clientRatio:
      # Set rect width to client width
      neww = self.clientSize.w
      newh = (neww.float / rectRatio).round.int
    else:
      # Set rect height to client height
      newh = sz.h
      neww = (newh.float * rectRatio).round.int
    (x: prect.x, y: prect.y, w: neww, h: newh)

proc font(self: Renderer, size: int): FontPtr =
  # Return properly sized font ptr from cache based on size
  let clampSize = clamp(size, fontRange)
  if clampSize notin self.fontCache:
    self.fontCache[clampSize] = openFont("fonts/DejaVuSans.ttf", clampSize)
  self.fontCache[clampSize]

proc font(self: Renderer, comp: DBComp, zoom: float): FontPtr =
  # Return properly sized font ptr from cache based on comp size
  let px = min(comp.bbox.w, comp.bbox.h)
  let scaledSize = (px.float * fontScale * zoom).round.int
  self.font(scaledSize)

proc highlight(comp: DBComp): float =
  if   (comp.selected, comp.hovering) == (false, false): 1.0
  elif (comp.selected, comp.hovering) == (false, true ): 1.2
  elif (comp.selected, comp.hovering) == (true,  false): 1.5
  else: 1.9

proc renderFilledRect*(rp: RendererPtr, rect: PRect, fillColor, penColor: ColorU32) =
  # explicit convertion to SDL2.Rect?
  rp.setDrawColor(fillColor.toColor)
  rp.fillRect(addr rect)
  rp.setDrawColor(penColor.toColor)
  rp.drawRect(addr rect)

proc renderOutlineRect*(rp: RendererPtr, rect: PRect, penColor: ColorU32) =
  # explicit convertion to SDL2.Rect?
  rp.setDrawColor(penColor.toColor)
  rp.drawRect(addr rect)

proc renderDBComp*(self: Renderer, vp: Viewport, comp: DBComp, prect: PRect, newSurface: bool): SurfacePtr {.discardable} =
  # Draw rectangle on surface using SDL2 renderer; return surface
  # if newSurface:
  #   create new Surface to draw to and use the zero'd version of prect; return surface
  # else:
  #   use self.sdlRenderer and the full prect

  var
    rp: RendererPtr
    surfRect: PRect
    err: SDL_Return
  
  if newSurface:
    result = createRGBSurface(0, prect.w, prect.h, 32, rmask, gmask, bmask, amask)
    rp = createSoftwareRenderer(result)
    surfRect = prect.zero 
  else:
    result = nil
    rp = self.sdlRenderer
    surfRect = prect

  # Draw rectangle
  rp.renderFilledRect(prect, comp.fillColor * comp.highlight, comp.penColor)
  when defined(debug):
    if err != SdlSuccess:
      raise newException(ValueError, &"Could not renderFilledRect: {getError()}")

  # Draw origin
  # Todo: There is something to be said here about model space
  # TODO: to world space to pixel space
  let
    fnx = proc(x: WType): PxType = (x.float * vp.zoom).round.cint
    fny = proc(y: WType): PxType = (y.float * vp.zoom).round.cint - 1
    opx: PxPoint = (fnx(comp.originToLeftEdge), fny(comp.originToTopEdge))
    extent = (10.0 * vp.zoom).round.cint
  rp.setDrawColor(Black.toColor)
  err = rp.drawLine(prect.x + opx.x - extent, prect.y + opx.y, prect.x + opx.x + extent, prect.y + opx.y)
  when defined(debug):
    if err != SdlSuccess:
      raise newException(ValueError, &"Could not drawLine: {getError()}")
  err = rp.drawLine(prect.x + opx.x, prect.y + opx.y - extent, prect.x + opx.x, prect.y + opx.y + extent)
  when defined(debug):
    if err != SdlSuccess:
      raise newException(ValueError, &"Could not drawLine: {getError()}")

  # Text to texture, then texture to renderer surface.
  # This gets converted back to texture again after return
  # So this could clearly be optimized and assembled when
  # creating cache
  # TODO: cache texts at different sizes
  if gAppOpts.enableText:
    let 
      (w, h) = (prect.w, prect.h)
      selstr = $comp.id & (if comp.selected: "*" else: "")
      font = self.font(comp, vp.zoom)
      textSurface = font.renderUtf8Blended(selstr.cstring, Black.toColor)
      (tsw, tsh) = (textSurface.w, textSurface.h)
      dstRect: PRect = (prect.x + (w div 2) - (tsw div 2),
                        prect.y + (h div 2) - (tsh div 2), tsw, tsh)
      pTextTexture = rp.createTextureFromSurface(textSurface)
    if pTextTexture.isNil:
      raise newException(ValueError, &"Text Texture pointer is nil: {getError()}")

    rp.copyEx(pTextTexture, nil, addr dstRect, -comp.rot.toFloat, nil)
    pTextTexture.destroy()

proc renderDBCompPixie*(vp: Viewport, comp: DBComp, prect: PRect): SurfacePtr =
  # Draw rectangle to new surface using pixie and return surface
  # vp is Viewport, used for zoom
  # comp is database object
  # prect is target rectangle with same aspect ratio as comp

  #let hrt = checkers(prect.w, prect.h)
  var pixiRect: shapes.Rect
  pixiRect.x = 0.0
  pixiRect.y = 0.0
  pixiRect.w = prect.w.float32
  pixiRect.h = prect.h.float32
  let shape = basicBox(pixiRect, comp.penColor)
  let pitch = prect.w * 4
  result = createRGBSurfaceFrom(
    shape.data[0].addr, 
    prect.w, prect.h, 
    32, pitch, 
    rmask, gmask, bmask, amask)

  if result.isNil:
    echo "Create surface failed"
    echo getError()

proc clearTextureCache*(self: Renderer) =
  # Clear all textures
  for texture in self.textureCache.values:
    texture.destroy()
  self.textureCache.clear()

proc clearTextureCache*(self: Renderer, id: CompID) =
  # Clear specific id from texture cache
  for sel in [false, true]:
    for hov in [false, true]:
      let key = (id, sel, hov)
      if key in self.textureCache:
        self.textureCache[key].destroy()
      self.textureCache.del(key)

proc getFromtextureCache(self: Renderer, id: CompID): TexturePtr =
  # Returns block texture, using cache if possible.
  #  Uses software renderer to draw to newly created surface,
  #  then creates texture from surface
  # Returns nil if any block dimension is zero or surface can't be created.
  # Throws exception if surface or texture can't be created.
  let 
    comp = self.doc.db[id]
    key = (id, comp.selected, comp.hovering)
  if self.textureCache.hasKey(key):
    self.textureCache[key]
  else:
    let 
      vp = self.editor.viewport
      prect = comp.bbox.toPRect(vp)
      cprect = self.clampRectSize(prect)
    if cprect.w == 0 or cprect.h == 0:
      # We are zoomed out too far
      return nil
    #let surface = renderDBComp(nil, vp, comp, cprect, zero=true) -> returns Surface
    let surface = renderDBCompPixie(vp, comp, cprect) # -> returns surface
    if surface.isNil:
      return nil
    let pTexture = self.sdlRenderer.createTextureFromSurface(surface)
    if pTexture.isNil:
      raise newException(ValueError, &"Texture pointer is nil from createTextureFromSurface: {getError()}")
    self.textureCache[key] = pTexture
    pTexture


proc blitFromtextureCache(self: Renderer) =
  # Copy from texture cache to screen via sdlrenderer
  let
    vp = self.editor.viewport
    sz: PxSize = self.editor.viewport.clientSize ##!! or self.clientSize?
    screenRect: WRect = (0.PxType, 0.PxType, sz.w, sz.h).toWrect(vp)
  var dstRect: PRect
  componentsVisible.setLen(0)
  for rect in self.doc.db.values:
    if isRectSeparate(rect.bbox, screenRect):
      continue
    let pTexture: TexturePtr = self.getFromtextureCache(rect.id)
    if not pTexture.isNil:
      componentsVisible.add(rect)
      dstRect = rect.bbox.toPRect(vp)
      self.sdlRenderer.copy(pTexture, nil, addr dstRect)




proc longestLine(lines: openArray[string]): string =
  # Returns longest substring terminated by newline
  var
    maxLen: int
    maxi: int
  for i, line in enumerate(lines):
    if line.len > maxLen:
      maxLen = line.len
      maxi = i
  lines[maxi]

proc renderText*(self: Renderer, x,y: cint, txt: string) =
  # Draws text at given location
  var txtSzW, txtSzH: cint
  let
    fnt = self.font(defFontSize)
    lines = txt.splitLines
    maxLine = longestLine(lines)

  discard sizeText(fnt, maxLine.cstring, addr txtSzW, addr txtSzH)
  txtSzH *= lines.len
  let dstRect: PRect = (x - txtSzW, y - txtSzH, txtSzW, txtSzH)
  let txtSurface = renderTextBlendedWrapped(fnt, txt, Black.toColor(), 0)
  let txtTexture = self.sdlRenderer.createTextureFromSurface(txtSurface)
  discard self.sdlRenderer.copy(txtTexture, nil, addr dstRect)
  txtTexture.destroy()
  txtSurface.destroy()

proc renderText*(self: Renderer, txt: string) =
  # Draws text at bottom right corner
  let window = self.sdlWindow
  self.renderText(window.getSize.x - 10,
                  window.getSize.y - 10, txt)



      
#[
Rendering options for pure SDL
1. Blitting to window renderer from sdl Texture cache
2. Rendering in real time directly to sdl surface

Rendering options for SDL and pixie
1. Blitting to window renderer...
  A. ...from sdl Texture cache (copied from pixie image cache on init and resize)
  C. ...from pixie image cache
2. Rendering in real time  
  B. Render to pixie image then blit to sdl surface


]# 


proc renderToScreen(self: Renderer) =
  # Render blocks to screen using default renderer
  let
    vp = self.editor.viewport
    sz: PxSize = self.clientSize
    screenRect: WRect = (0.PxType, 0.PxType, sz.w, sz.h).toWrect(vp)
  for comp in self.doc.db.values:
    if isRectSeparate(comp.bbox, screenRect):
      continue
    let
      prect = comp.bbox.toPRect(vp)
      cprect = self.clampRectSize(prect)
    self.renderDBComp(vp, comp, cprect, newSurface=false) # -> Returns nil




proc lineAlpha(step: int): int =
  let idx = max(0, step - alphaOffset)
  if idx < stepAlphas.len:
    result = stepAlphas[idx]
  else:
    result = 255
proc toWorldF(pt: PxPoint, vp: Viewport): tuple[x,y: float] =
  let
    x = ((pt.x - vp.pan.x).float / vp.zoom)
    y = ((pt.y - vp.pan.y).float / vp.zoom)
  (x, y)

proc drawScale(self: Renderer) =
  let
    rp = self.sdlRenderer
    grid = self.doc.grid
    vp = self.editor.viewport
    size = self.clientSize
    left = 150
    majDelta = grid.minDelta(Major).x
    minDelta = grid.minDelta(Minor).x
    majDeltaPx = (majDelta.float * vp.zoom).round.int
    minDeltaPx = (minDelta.float * vp.zoom).round.int
    botMajor = size.h - 100
    botMinor = size.h - 60

  # Major line
  rp.setDrawColor(DarkSlateGray.toColor)
  var r1, r2, r3: sdl2.Rect
  let ht = 11
  r1 = (left, botMajor - 1, majDeltaPx, 3)
  r2 = (left, botMajor - (ht div 2), 3, ht)
  r3 = (left + majDeltaPx, botMajor - (ht div 2), 3, ht)
  rp.fillRect(r1)
  rp.fillRect(r2)
  rp.fillRect(r3)

  # Minor line
  r1 = (left, botMinor - 1, minDeltaPx, 3)
  r2 = (left, botMinor - (ht div 2), 3, ht)
  r3 = (left + minDeltaPx, botMinor - (ht div 2), 3, ht)
  rp.fillRect(r1)
  rp.fillRect(r2)
  rp.fillRect(r3)

  # Labels
  let
    majorLabel = if WType is SomeInteger: &"{majDelta}"
                 else: &"{majDelta}"
    minorLabel = if WType is SomeInteger: &"{minDelta}"
                 else: &"{minDelta}"
  self.renderText(left - 5, botMajor + 12, majorLabel)
  self.renderText(left - 5, botMinor + 12, minorLabel)

proc drawGrid*(self: Renderer) =
  # Grid spaces are in world coords.  Need to convert to pixels
  let
    rp = self.sdlRenderer
    vp = self.editor.viewport
    size = self.clientSize
    grid = self.doc.grid
    upperLeft: PxPoint = (0, 0)
    lowerRight: PxPoint = (size.w - 1, size.h - 1)

  if grid.mVisible:
    let
      worldStartMinor: tuple[x, y: float] = upperLeft.toWorldF(vp).snap(grid, scale=Minor)
      worldEndMinor:   tuple[x, y: float] = lowerRight.toWorldF(vp).snap(grid, scale=Minor)
      worldStepMinor:  tuple[x, y: WType] = minDelta(grid, scale=Minor)
      worldStartMajor: tuple[x, y: float] = upperLeft.toWorldF(vp).snap(grid, scale=Major)
      worldEndMajor:   tuple[x, y: float] = lowerRight.toWorldF(vp).snap(grid, scale=Major)
      worldStepMajor:  tuple[x, y: WType] = minDelta(grid, scale=Major)
      xStepPxColor:    int = (worldStepMinor.x.float * vp.zoom).round.int

    # Minor lines
    if grid.mDotsOrLines == Lines:
      rp.setDrawColor(LightSlateGray.toColorU32(lineAlpha(xStepPxColor)).toColor)
      for xwf in arange(worldStartMinor.x .. worldEndMinor.x, worldStepMinor.x.float):
        let xpx = (xwf * vp.zoom + vp.pan.x.float).round.cint
        rp.drawLine(xpx, 0, xpx, size.h - 1)

      for ywf in arange(worldStartMinor.y .. worldEndMinor.y, worldStepMinor.y.float):
        let ypx = (ywf * vp.zoom + vp.pan.y.float).round.cint
        rp.drawLine(0, ypx, size.w - 1, ypx)

    elif grid.mDotsOrLines == Dots:
      var pts: seq[Point]
      rp.setDrawColor(LightSlateGray.toColorU32(lineAlpha(xStepPxColor)).toColor)
      for xwf in arange(worldStartMinor.x .. worldEndMinor.x, worldStepMinor.x.float):
        let xpx = (xwf * vp.zoom + vp.pan.x.float).round.cint
        for ywf in arange(worldStartMinor.y .. worldEndMinor.y, worldStepMinor.y.float):
          let ypx = (ywf * vp.zoom + vp.pan.y.float).round.cint
          pts.add((xpx-1, ypx-1))
          pts.add((xpx-1, ypx  ))
          pts.add((xpx,   ypx-1))
          pts.add((xpx,   ypx  ))
      rp.drawPoints(cast[ptr Point](pts[0].addr), pts.len.cint)

    # Major lines
    if grid.mDotsOrLines == Lines:
      rp.setDrawColor(DarkSlateGray.toColorU32(lineAlpha(xStepPxColor)).toColor)
      for xwf in arange(worldStartMajor.x .. worldEndMajor.x, worldStepMajor.x.float):
        let xpx = (xwf * vp.zoom + vp.pan.x.float).round.cint
        rp.drawLine(xpx, 0, xpx, size.h - 1)

      for ywf in arange(worldStartMajor.y .. worldEndMajor.y, worldStepMajor.y.float):
        let ypx = (ywf * vp.zoom + vp.pan.y.float).round.cint
        rp.drawLine(0, ypx, size.w - 1, ypx)
    
    elif grid.mDotsOrLines == Dots:
      var pts: seq[Point]
      rp.setDrawColor(Black.toColor)
      for xwf in arange(worldStartMajor.x .. worldEndMajor.x, worldStepMajor.x.float):
        let xpx = (xwf * vp.zoom + vp.pan.x.float).round.cint
        for ywf in arange(worldStartMajor.y .. worldEndMajor.y, worldStepMajor.y.float):
          let ypx = (ywf * vp.zoom + vp.pan.y.float).round.cint
          pts.add((xpx-1, ypx-1))
          pts.add((xpx-0, ypx-1))
          pts.add((xpx+1, ypx-1))
          pts.add((xpx-1, ypx-0))
          pts.add((xpx-0, ypx-0))
          pts.add((xpx+1, ypx-0))
          pts.add((xpx-1, ypx+1))
          pts.add((xpx-0, ypx+1))
          pts.add((xpx+1, ypx+1))
      rp.drawPoints(cast[ptr Point](pts[0].addr), pts.len.cint)

  if grid.mOriginVisible:
    let
      extent: PxType = 25.0 * vp.zoom
      o: PxPoint = (0, 0).toPixel(vp)
        
    rp.setDrawColor(colors.DarkRed.toColor())

    # Horizontals
    rp.drawLine(o.x - extent, o.y,   o.x + extent, o.y    )
    rp.drawLine(o.x - extent, o.y-1, o.x + extent, o.y - 1)
    rp.drawLine(o.x - extent, o.y+1, o.x + extent, o.y + 1)
    
    # Verticals
    rp.drawLine(o.x,     o.y - extent, o.x,     o.y + extent)
    rp.drawLine(o.x - 1, o.y - extent, o.x - 1, o.y + extent)
    rp.drawLine(o.x + 1, o.y - extent, o.x + 1, o.y + extent)

    # Scale
    self.drawScale()


proc drawEverything*(self: Renderer) =
  # Typically called from OnPaint
  self.sdlRenderer.setDrawColor(self.backgroundColor)
  self.sdlRenderer.clear()
  return
  self.drawGrid()

  # Try a few methods to draw rectangles
  when defined(noTextureCache):
    self.renderToScreen()
  else:
    self.blitFromtextureCache()

  # Draw various boxes and text, then done
  #self.updateDestinationBox()
  if gAppOpts.enableDstRect:
    self.sdlRenderer.renderOutlineRect(self.editor.dstRect.toPRect(self.editor.viewport), DarkOrchid)
  if gAppOpts.enableBbox:
    #self.updateBoundingBox()
    self.sdlRenderer.renderOutlineRect(self.editor.allBbox.toPRect(self.editor.viewport).grow(1), Green)
  self.sdlRenderer.renderFilledRect(self.editor.selectBox,
                                    fillColor=(r:0, g:102, b:204, a:70).RGBATuple.toColorU32,
                                    penColor=(r:0, g:120, b:215, a:255).RGBATuple.toColorU32)
  var txt: string
  txt &= &"pan: {self.editor.viewport.pan}\n"
  txt &= &"zClicks: {self.editor.viewport.zClicks}\n"
  txt &= &"level: {self.editor.viewport.zCtrl.logStep}\n"
  txt &= &"rawZoom: {self.editor.viewport.rawZoom:.3f}\n"
  txt &= &"zoom: {self.editor.viewport.zoom:.3f}\n"
  txt &= &"smoothDelta: {minDelta(self.doc.grid, scale=None)}\n"
  txt &= &"tinyDelta: {minDelta(self.doc.grid, scale=Tiny)}\n"
  txt &= &"minorDelta: {minDelta(self.doc.grid, scale=Minor)}\n"
  let majdelt = minDelta(self.doc.grid, scale=Major)
  let pxwidth = (majdelt.x.float * self.editor.viewport.zoom).round.int
  txt &= &"majorDelta: {majdelt}\n"
  txt &= &"majorPx: {pxwidth}"
  
  self.renderText(txt)
  self.sdlRenderer.present()

  # release(gLock)
