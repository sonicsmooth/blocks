import winim/inc/winuser

# These are constant values that go across 
# threads or from one frame to another

# type
#   UserMsgID* {.size: sizeof(int32).} = enum 
#     idMsgMouseMove = WM_USER,
#     idMsgSize, idMsgSlider, idMsgAlgUpdate, idMsgGridVisible,
#     idMsgSubFrameClosing

const
  idMsgMouseMove*       = WM_USER + 0
  idMsgSize*            = WM_USER + 1
  idMsgSlider*          = WM_USER + 2
  idMsgAlgUpdate*       = WM_USER + 3
  
  # Grid Control
  idMsgGridDivisions*   = WM_USER + 4
  idMsgGridSnap*        = WM_USER + 5
  idMsgGridDynamic*     = WM_USER + 6
  idMsgGridVisible*     = WM_USER + 7
  idMsgGridDots*        = WM_USER + 8
  idMsgGridLines*       = WM_USER + 9
  
  # Frames
  idMsgSubFrameClosing* = WM_USER + 10

  
  # Random thread stuff
  ALG_NO_INIT_BMP*  = 0
  ALG_INIT_BMP*     = 10