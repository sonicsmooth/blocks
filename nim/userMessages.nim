import winim/inc/winuser

# These are constant values that go across 
# threads or from one frame to another

type
  UserIDs* = enum
    idMouseMove = WM_USER,
    idSize, idSlider, idAlgUpdate, idGridVisible

const
  ALG_NO_INIT_BMP*  = 0
  ALG_INIT_BMP*     = 1