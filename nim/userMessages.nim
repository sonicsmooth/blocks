import winim/inc/winuser

# These are constant values that go across 
# threads or from one frame to another

const
  idMsgMouseMove*     = WM_USER +  0
  idMsgSize*          = WM_USER +  1
  idMsgSlider*        = WM_USER +  2
  idMsgAlgUpdate*     = WM_USER +  3
  
  # Grid Control
  idMsgGridZoom*            = WM_USER + 4
  idMsgGridSizeX*           = WM_USER + 5
  idMsgGridSizeY*           = WM_USER + 6
  idMsgGridDivisionsSelect* = WM_USER + 7  # change official selection
  idMsgGridDivisionsValue*  = WM_USER + 8  # change text if selection not available
  idMsgGridDivisionsReset*  = WM_USER + 9  # Reset to legitimate values after grid size change
  idMsgGridDensity*         = WM_USER + 10
  idMsgGridSnap*            = WM_USER + 11
  idMsgGridDynamic*         = WM_USER + 12
  idMsgGridBaseSync*        = WM_USER + 13
  idMsgGridVisible*         = WM_USER + 14
  idMsgGridDots*            = WM_USER + 15
  idMsgGridLines*           = WM_USER + 16
  
  # Frames
  idMsgGridCtrlFrameClosing* = WM_USER + 14

  
  # Random thread stuff
  ALG_NO_INIT_BMP*  = 0
  ALG_INIT_BMP*     = 10