import std/[math,
            sequtils,
            strformat,
            strutils]
import sdl2 except Color
import sdl2/ttf

import arange
import colors, colors_sdl
import grid
import viewport
import world

const
  alphaOffset = 20
  stepAlphas = arange(60 .. 255, alphaOffset).toSeq


proc longestString(lines: openArray[string]): string =
  # Returns longest substring terminated by newline
  var  maxLen, maxi: int
  for i, line in lines:
    if line.len > maxLen:
      maxLen = line.len
      maxi = i
  lines[maxi]


proc renderText*(rp: RendererPtr, x,y: cint, txt: string, font: FontPtr) =
  # Draws text at given location
  # TODO: provide left/mid/right and top/mid/down alignment
  let
    lines = txt.splitLines
    maxLine = longestString(lines)

  var txtSzW, txtSzH: cint
  discard sizeText(font, maxLine.cstring, addr txtSzW, addr txtSzH)
  txtSzH *= lines.len
  let texRect = rect(x - txtSzW, y - txtSzH, txtSzW, txtSzH)
  let txtSurface = renderTextBlendedWrapped(font, txt, Black, 0)
  let txtTexture = rp.createTextureFromSurface(txtSurface)
  discard rp.copy(txtTexture, nil, addr texRect)
  txtTexture.destroy()
  txtSurface.destroy()


proc drawScale*(rp: RendererPtr, vp: Viewport, grid: Grid, font: FontPtr) =
  let
    csz = vp.clientSize
    left = 150
    majDelta = grid.minDelta(Major).x
    minDelta = grid.minDelta(Minor).x
    majDeltaPx = (majDelta.float * vp.zoom).round.int
    minDeltaPx = (minDelta.float * vp.zoom).round.int
    botMajor = csz.h - 100
    botMinor = csz.h - 60

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

  rp.renderText(left, botMajor + 12, majorLabel, font)
  rp.renderText(left, botMinor + 12, minorLabel, font)

# TODO: replace with a fn from world.nim
proc toWorldF(pt: PxPoint, vp: Viewport): tuple[x,y: float] =
  let
    x = ((pt.x - vp.pan.x).float / vp.zoom)
    y = ((pt.y - vp.pan.y).float / vp.zoom)
  (x, y)

proc lineAlpha(step: int): int =
  let idx = max(0, step - alphaOffset)
  if idx < stepAlphas.len:
    result = stepAlphas[idx]
  else:
    result = 255


proc drawGrid*(rp: RendererPtr, vp: Viewport, grid: Grid) =
  # Grid spaces are in world coords.  Need to convert to pixels
  let
    size = vp.clientSize
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


