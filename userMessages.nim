import winim/inc/winuser

# These are constant values that go across 
# threads or from one frame to another

const
  idMsgMouseMove*     = WM_USER +  0
  idMsgSize*          = WM_USER +  1
  idMsgSlider*        = WM_USER +  2
  idMsgAlgUpdate*     = WM_USER +  3
  
  # Grid Control
  idMsgGridSizeX*     = WM_USER +  4
  idMsgGridSizeY*     = WM_USER +  5
  idMsgGridDivisions* = WM_USER +  6
  idMsgGridDensity*   = WM_USER +  7
  idMsgGridSnap*      = WM_USER +  8
  idMsgGridDynamic*   = WM_USER +  9
  idMsgGridBaseSync*  = WM_USER + 10
  idMsgGridVisible*   = WM_USER + 11
  idMsgGridDots*      = WM_USER + 12
  idMsgGridLines*     = WM_USER + 13
  
  # Frames
  idMsgSubFrameClosing* = WM_USER + 14

  
  # Random thread stuff
  ALG_NO_INIT_BMP*  = 0
  ALG_INIT_BMP*     = 10