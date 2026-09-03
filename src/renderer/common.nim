
import std/[os,
            sequtils]

# Okay to import the whole thing because we're in renderer directory
import rects

const 
  gCandidates = ["../fonts/DejaVuSans.ttf",
                 "../fonts/Roboto-Regular_1.ttf",
                 "../fonts/Ubuntu-Regular_1.ttf"]
  fontRange*: Slice[int] = 1..50000
  defFontSize* = 25

proc fontCandidates*(): seq[string] =
  result = gCandidates.toSeq
  result.add(getEnv("WINDIR") / "Fonts" / "arial.ttf")
  result.add(getEnv("WINDIR") / "Fonts" / "segoeui.ttf")

proc toPixelScale*[T:WPoint](pt: T, zoom: float): PxPoint =
  (pt[0] * zoom, pt[1] * zoom)

proc pxOrigin*(comp: DBComp, zoom: float): PxPoint =
  # Return the origin position in pixels
  comp.originToTopLeft(false).toPixelScale(zoom)


when isMainModule:
  echo fontCandidates()