import std/[enumerate,
            sequtils,
            strutils, 
            strformat, 
            math,
            tables,
            ]
import wNim/wTypes
import sdl2 except Color
import sdl2/ttf
import document, grid, editor, rotation
import rects, appopts
import pixieshapes
import colors, colors_sdl
import reporting
from arange import arange



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
    fontCache: Table[int, FontPtr]
    visibleComponents*: seq[DBComp]


const
  fontRange: Slice[int] = 6..100  
  fontScale = 0.45
  defFontSize = 25
  alphaOffset = 20
  stepAlphas = arange(60 .. 255, alphaOffset).toSeq
  rmask = 0xff.shl(24).uint32
  gmask = 0xff.shl(16).uint32
  bmask = 0xff.shl( 8).uint32
  amask = 0xff.shl( 0).uint32


proc newRenderer*(): Renderer =
  result = new Renderer
  result.backgroundColor = MintCream

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

proc font(self: Renderer, size: int): FontPtr =
  # Return properly sized font ptr from cache based on size
  let clampSize = clamp(size, fontRange)
  if clampSize notin self.fontCache:
    self.fontCache[clampSize] = openFont("../fonts/DejaVuSans.ttf", clampSize)
  self.fontCache[clampSize]

proc font(self: Renderer, comp: DBComp, zoom: float): FontPtr =
  # Return properly sized font ptr from cache based on comp size
  let px = min(comp.wbbox.w, comp.wbbox.h)
  let scaledSize = (px.float * fontScale * zoom).round.int
  self.font(scaledSize)

#proc highlight(comp: DBComp): float =
proc highlight(selected, hovering: bool): float =
  if   (selected, hovering) == (false, false): 1.0
  elif (selected, hovering) == (false, true ): 1.2
  elif (selected, hovering) == (true,  false): 1.5
  else: 1.9

#[ Component rendering options:
  1. Default renderer -> rp.drawRect
  2. Software renderer -> rp.drawRect -> cache -> blit
  3. Texture as rendering target -> rp.drawRect -> cache -> blit
  4. Pixie.Image, then update texture cache, then blit to sdlRenderer 
  5. Lock texture then draw with pixie, then unlock and blit to sdlRenderer ]# 

proc renderFilledRect*(rp: RendererPtr, rect: PRect, fillColor, penColor: ColorRGBA) =
  # explicit convertion to SDL2.Rect?
  rp.setDrawColor(fillColor)
  rp.fillRect(addr rect)
  rp.setDrawColor(penColor)
  rp.drawRect(addr rect)

proc renderOutlineRect(rp: RendererPtr, rect: PRect, penColor: ColorRGBA) =
  # explicit convertion to SDL2.Rect?
  rp.setDrawColor(penColor)
  rp.drawRect(addr rect)

proc renderCompOrigin(rp: RendererPtr, comp: DBComp, prect: PRect, vp: Viewport, rot: bool) =
  # Todo: There is something to be said here about model space
  # TODO: to world space to pixel space
  # Pass rot to origin..edge functions.
  # When rot is false, everything is treated as an unrotated component
  # The opx here is identical to comp.rotationPoint(vp) when rot is false
  # There appears to be a -1 in here for some reason
  let
    fnx = proc(x: WType): PxType = (x.float * vp.zoom).round.cint
    fny = proc(y: WType): PxType = (y.float * vp.zoom).round.cint - 1
    opx: PxPoint = (fnx(comp.originToLeftEdge(rot)), fny(comp.originToTopEdge(rot)))
    extent = (10.0 * vp.zoom).round.cint
  rp.setDrawColor(Black)
  rp.drawLine(prect.x + opx.x - extent, prect.y + opx.y, prect.x + opx.x + extent, prect.y + opx.y)
  rp.drawLine(prect.x + opx.x, prect.y + opx.y - extent, prect.x + opx.x, prect.y + opx.y + extent)

proc renderCompText(rp: RendererPtr, comp: DBComp, font: FontPtr, prect: PRect, rot: bool) =
  # Render component text
  # Text to texture, then texture to renderer surface.
  # This gets converted back to texture again after return
  # So this could clearly be optimized and assembled when
  # creating cache
  let 
    (w, h) = (prect.w, prect.h)
    selstr = $comp.id # & (if comp.selected: "*" else: "")
    textSurface = font.renderUtf8Blended(selstr.cstring, Black)
    textTexture = rp.createTextureFromSurface(textSurface)
    (tsw, tsh) = (textSurface.w, textSurface.h)
    texRect: PRect = (prect.x + (w div 2) - (tsw div 2),
                      prect.y + (h div 2) - (tsh div 2), tsw, tsh)
  if textTexture.isNil:
    raise newException(ValueError, &"Text Texture pointer is nil: {getError()}")

  if rot:
    rp.copyEx(textTexture, nil, addr texRect, comp.rot.toFloat, nil)
  else:
    rp.copyEx(textTexture, nil, addr texRect, 0, nil)
  textSurface.destroy()
  textTexture.destroy()

proc chooseRenderer(self: Renderer): RendererPtr =
  if self.sdlSoftwareRenderer.isNil:
    self.sdlRenderer
  else:
    self.sdlSoftwareRenderer

proc choosePRect(self: Renderer, comp: DBComp, rot: bool): PRect =
  # Rot true means return the real screen bounding box
  # Rot false means return zero-origin rectangle from unrotated comp
  if rot:
    comp.pbbox(self.editor.viewport)
  else:
    let psize = comp.pxSize(self.editor.viewport)
    (x: 0, y:0, w: psize.w, h: psize.h)

proc renderDBCompSDL(self: Renderer, comp: DBComp, hov, sel: bool, rot: bool=false) =
  # Draw rectangle, origin, and its text using SDL2 renderer to prect
  # prect is rectangle in pixels
  # hov, sel is whether this is hovering and/or selected
  # rot: true means use default rotated bbox and rotate text
  # rot: false means render as R0, with text unrotated, and box zero'd
  # Generally SDLDirect will use rot=true and false otherwise
  
  let 
    vp = self.editor.viewport
    rp = self.chooseRenderer()
    prect = self.choosePRect(comp, rot)
    highlightFactor = highlight(hov, sel)
    font = self.font(comp, vp.zoom)

  rp.renderFilledRect(prect, comp.fillColor * highlightFactor, comp.penColor)
  if sel:
    rp.renderOutlineRect(prect.shrink(1), comp.penColor)
    rp.renderOutlineRect(prect.shrink(2), comp.penColor * 2)
    rp.renderOutlineRect(prect.shrink(3), comp.penColor * 3)
    rp.renderOutlineRect(prect.shrink(4), comp.penColor * 4)
  rp.renderCompOrigin(comp, prect, vp, rot)
  if gAppOpts.enableText:
    rp.renderCompText(comp, font, prect, rot)


proc renderDBCompPixie*(comp: DBComp, hov, sel: bool): SurfacePtr =
  # Draw rectangle to new surface using pixie and return surface
  # comp is database object
  # prect is target rectangle with same aspect ratio as comp
  var prect: PRect # fill in later
  let highlightFactor = highlight(hov, sel)
  var col1 = comp.fillColor * 1.0 * highlightFactor
  var col2 = comp.fillColor * 0.8 * highlightFactor
  col1.a = 200
  col2.a = 200
  let shape = gradientBox(prect.w, prect.h, comp.penColor, col1, col2)
  # Swizzle the mask order because of endianness
  result = createRGBSurfaceFrom(
    shape.data[0].addr, 
    prect.w, prect.h, 
    32, prect.w * 4, 
    amask, bmask, gmask, rmask)
  if result.isNil:
    echo "Create surface failed"
    echo getError()


# TODO: longestString
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
  let texRect: PRect = (x - txtSzW, y - txtSzH, txtSzW, txtSzH)
  let txtSurface = renderTextBlendedWrapped(fnt, txt, Black, 0)
  let txtTexture = self.sdlRenderer.createTextureFromSurface(txtSurface)
  discard self.sdlRenderer.copy(txtTexture, nil, addr texRect)
  txtTexture.destroy()
  txtSurface.destroy()
proc renderText*(self: Renderer, txt: string) =
  # Draws text at bottom right corner
  let window = self.sdlWindow
  self.renderText(window.getSize.x - 10,
                  window.getSize.y - 10, txt)
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
  let
    vp = self.editor.viewport
    sz = self.editor.viewport.clientSize
  (0.PxType, 0.PxType, sz.w, sz.h)

proc buildTexture(self: Renderer, comp: DBComp, rmethod: RenderMethod, 
                  hov, sel: bool, texSz: PxSize): TexturePtr = 
  case rmethod
  of SDLTexture:
    let fmt = self.sdlWindow.getPixelFormat()
    result = self.sdlRenderer.createTexture(fmt, SDL_TEXTUREACCESS_TARGET, texSz.w, texSz.h)
    self.sdlRenderer.setRenderTarget(result)
    self.renderDBCompSDL(comp, hov, sel, false)
    self.sdlRenderer.setRenderTarget(nil)
  of PixieTexture:
    let surface = renderDBCompPixie(comp, hov, sel)
    result = self.sdlRenderer.createTextureFromSurface(surface)
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

proc drawDBComps(self: Renderer, rmethod: RenderMethod) =
  self.visibleComponents.setLen(0)
  let vp = self.editor.viewport
  for comp in self.doc.db.values:
    let pbb = comp.pbbox(vp) # rotated
    if isRectSeparate(pbb, self.screenRectP):
      continue
    let cprect = self.clampRectSize(pbb)
    if cprect.w == 0 or cprect.h == 0: continue
    let hov = self.editor.isHovering(comp.id)
    let sel = self.editor.isSelected(comp.id)
    if rmethod == SDLDirect:
      self.renderDBCompSDL(comp, hov, sel, true)
    else:
      let key = (comp.id, hov, sel)
      let texSz = comp.pxSize(vp)
      if key notin self.textureCache:
        self.textureCache[key] = self.buildTexture(comp, rmethod, hov, sel, texSz)
      self.drawCachedTexture(comp, self.textureCache[key], vp)
    self.visibleComponents.add(comp)

proc drawSelectBox(self: Renderer) =
  if self.editor.selectBox.w == 0 or
     self.editor.selectBox.h == 0:
      return
  let fillColor = ColorRGBA(r: 0, g:102, b: 204, a:70)
  let penColor = ColorRGBA(r: 0, g:120, b: 215, a:255)
  self.sdlRenderer.renderFilledRect(self.editor.selectBox, fillColor, penColor)

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
    size = self.editor.viewport.clientSize
    left = 150
    majDelta = grid.minDelta(Major).x
    minDelta = grid.minDelta(Minor).x
    majDeltaPx = (majDelta.float * vp.zoom).round.int
    minDeltaPx = (minDelta.float * vp.zoom).round.int
    botMajor = size.h - 100
    botMinor = size.h - 60

  # Major line
  rp.setDrawColor(DarkSlateGray)
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
    size = self.editor.viewport.clientSize
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
      var lsg = LightSlateGray
      lsg.a = lineAlpha(xStepPxColor).uint8
      rp.setDrawColor(lsg)
      for xwf in arange(worldStartMinor.x .. worldEndMinor.x, worldStepMinor.x.float):
        let xpx = (xwf * vp.zoom + vp.pan.x.float).round.cint
        rp.drawLine(xpx, 0, xpx, size.h - 1)

      for ywf in arange(worldStartMinor.y .. worldEndMinor.y, worldStepMinor.y.float):
        let ypx = (ywf * vp.zoom + vp.pan.y.float).round.cint
        rp.drawLine(0, ypx, size.w - 1, ypx)

    elif grid.mDotsOrLines == Dots:
      var pts: seq[Point]
      var lsg = LightSlateGray
      lsg.a = lineAlpha(xStepPxColor).uint8
      rp.setDrawColor(lsg)
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
      var lsg = LightSlateGray
      lsg.a = lineAlpha(xStepPxColor).uint8
      rp.setDrawColor(lsg)
      for xwf in arange(worldStartMajor.x .. worldEndMajor.x, worldStepMajor.x.float):
        let xpx = (xwf * vp.zoom + vp.pan.x.float).round.cint
        rp.drawLine(xpx, 0, xpx, size.h - 1)

      for ywf in arange(worldStartMajor.y .. worldEndMajor.y, worldStepMajor.y.float):
        let ypx = (ywf * vp.zoom + vp.pan.y.float).round.cint
        rp.drawLine(0, ypx, size.w - 1, ypx)
    
    elif grid.mDotsOrLines == Dots:
      var pts: seq[Point]
      rp.setDrawColor(Black)
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
        
    rp.setDrawColor(DarkRed)

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
  let bg = self.backgroundColor
  self.sdlRenderer.setDrawColor(bg)
  self.sdlRenderer.clear()
  self.drawGrid()
  self.drawDBComps(gAppOpts.renderMethod)
  self.drawSelectBox()

  # # Draw various boxes and text, then done
  # #self.updateDestinationBox()
  # if gAppOpts.enableDstRect:
  #   self.sdlRenderer.renderOutlineRect(self.editor.texRect.toPRect(self.editor.viewport), DarkOrchid)
  # if gAppOpts.enableBbox:
  #   #self.updateBoundingBox()
  #   self.sdlRenderer.renderOutlineRect(self.editor.allBbox.toPRect(self.editor.viewport).grow(1), Green)
  self.sdlRenderer.present()
  # var txt: string
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
