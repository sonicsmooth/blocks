#====================================================================
#
#               wNim - Nim's Windows GUI Framework
#                Copyright (c) Chen Kai-Hung, Ward
#
#====================================================================

#import resource/resource
import wNim/[wApp, wMacros, wFrame, wMessageDialog]

# wNim's class/object use following naming convention.
# 1. Class name starts with 'w' and define as ref object. e.g. wObject.
# 2. Every class have init(self: wObject) as initializer.
# 3. Provides an Object() proc to quickly get the ref object.

# wClass (defined in wMacros) provides a convenient way to define wNim class.

type
  wMainFrame* = ref object of wFrame
    mJunkStr: string


wClass(wMainFrame of wFrame):
  # Constructor is generated from initializer and finalizer automatically.

  proc init*(self: wMainFrame, size: wSize) =
    wFrame(self).init(title="junk", size=size)


