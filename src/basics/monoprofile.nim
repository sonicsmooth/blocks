import std/[monotimes,
           times]


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
