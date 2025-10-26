import winim/inc/winuser

# These are constant values that go across 
# threads or from one frame to another

type
  UserMsgID* {.size: 4.} = enum 
    idMsgMouseMove = WM_USER,
    idMsgSize, idMsgSlider, idMsgAlgUpdate, idMsgGridShow,
    idMsgSubFrameClosing

const
  ALG_NO_INIT_BMP*  = 0
  ALG_INIT_BMP*     = 1