
proc reportNil*(txt: string): bool =
  when defined(debug):
    echo txt & " is nil"
    echo getStackTrace()
  false

proc reportNotReady*(txt: string): bool =
  when defined(debug):
    echo txt & " is not ready"
    echo getStackTrace()
  false