
import std/[monotimes,
            os,
            sequtils,
            times]


const 
  gCandidates = ["../fonts/DejaVuSans.ttf",
                 "../fonts/Roboto-Regular_1.ttf",
                 "../fonts/Ubuntu-Regular_1.ttf"]
  fontRange*: Slice[int] = 4..1000
  defFontSize* = 25


template timeIt*(msg: string, body: untyped) =
  # use this like
  # timeIt("The thing to be timed is"):
  #   let whatever = theExpensiveCall()
  #   whatever.anotherCall()
  let t0 = now()
  body
  let elapsed = (now() - t0).inMilliseconds
  echo msg, ": ", elapsed, " ms"

proc fontCandidates*(): seq[string] =
  result = gCandidates.toSeq
  result.add(getEnv("WINDIR") / "Fonts" / "arial.ttf")
  result.add(getEnv("WINDIR") / "Fonts" / "segoeui.ttf")

when isMainModule:
  echo fontCandidates()