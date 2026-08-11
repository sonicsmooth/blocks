
import std/[math, 
            options, 
            os, 
            tables]
import sdl2/ttf
import rects


const
  rmask* = 0xff.shl(24).uint32
  gmask* = 0xff.shl(16).uint32
  bmask* = 0xff.shl( 8).uint32
  amask* = 0xff.shl( 0).uint32
  fontRange*: Slice[int] = 6..100  
  fontScale* = 0.45
  defFontSize* = 25

var
  gFontCache: Table[int, FontPtr]
  gFontName: Option[string]

proc tryOpenFont(paths: openArray[string], size: cint): FontPtr =
  for p in paths:
    if isNone(gFontName) and not existsFile(p):
      echo "Could not find ", p
      continue

    result = ttf.openFont(p, size)
    if not result.isNil:
      if gFontName.isNone:
        gFontName = some(p)
        echo "Loaded ", p
      return result

proc font*(size: int): FontPtr =
  # Return properly sized font ptr from cache based on size
  let clampSize = clamp(size, fontRange)
  if clampSize notin gFontCache:
    let candidates = @[
      "../fonts/DejaVuSans.ttf",
      "../fonts/Roboto-Regular_1.ttf",
      "../fonts/Ubuntu-Regular_1.ttf",
      getEnv("WINDIR") / "Fonts" / "arial.ttf",
      getEnv("WINDIR") / "Fonts" / "segoeui.ttf",
    ]
    let fnt = tryOpenFont(candidates, clampSize.cint)
    gFontCache[clampSize] = fnt
  gFontCache[clampSize]


proc font*(comp: DBComp, zoom: float): FontPtr =
  # Return properly sized font ptr from cache based on comp size
  let px = min(comp.wbbox.w, comp.wbbox.h)
  let scaledSize = (px.float * fontScale * zoom).round.int
  font(scaledSize)
