import winim/inc/winuser

# These are constant values that go across 
# threads or from one frame to another

# type
#   UserMsgID* {.size: sizeof(int32).} = enum 
#     idMsgMouseMove = WM_USER,
#     idMsgSize, idMsgSlider, idMsgAlgUpdate, idMsgGridShow,
#     idMsgSubFrameClosing

const
  idMsgMouseMove*       = WM_USER + 0
  idMsgSize*            = WM_USER + 1
  idMsgSlider*          = WM_USER + 2
  idMsgAlgUpdate*       = WM_USER + 3
  idMsgGridShow*        = WM_USER + 4
  idMsgSubFrameClosing* = WM_USER + 5

  ALG_NO_INIT_BMP*  = 0
  ALG_INIT_BMP*     = 10