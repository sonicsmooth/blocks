
import std/[monotimes,
            os,
            sequtils,
            times]

import rects

const 
  gCandidates = ["../fonts/DejaVuSans.ttf",
                 "../fonts/Roboto-Regular_1.ttf",
                 "../fonts/Ubuntu-Regular_1.ttf"]
  fontRange*: Slice[int] = 1..50000
  defFontSize* = 25


template timeItms*(flag: untyped, msg: string, body: untyped) =
  when defined(flag):
    let t0 = now()
  body
  when defined(flag):
    let elapsed = (now() - t0).inMilliseconds
    echo msg, ": ", elapsed, " ms"

template timeItus*(flag: untyped, msg: string, body: untyped) =
  when defined(flag):
    let t0 = now()
  body
  when defined(flag):
    let elapsed = (now() - t0).inMicroSeconds
    echo msg, ": ", elapsed, " us"

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