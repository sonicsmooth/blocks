import wnim
import wNim/private/wTypes


proc appDpiScale*[T:(int, int)](value: T): T =
  let d = wAppGetDpi()
  (value[0] * d div 96, value[1] * d div 96)

proc appDpiScale*(value: int): int =
  value * wAppGetDpi() div 96

# Don't call wAppGetDpi() before the framework has initialized
# Otherwise the value returned is 96, whic is probably not what you want
