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
  idMsgGridRequestX*        = WM_USER + 6  # user-input value
  idMsgGridSizeY*           = WM_USER + 7  # what gets sent for display
  idMsgGridRequestY*        = WM_USER + 8 
  idMsgGridDivisionsSelect* = WM_USER + 9   # change official selection
  idMsgGridDivisionsValue*  = WM_USER + 10  # change text if selection not available
  idMsgGridDivisionsReset*  = WM_USER + 11  # Reset to legitimate values after grid size change
  idMsgGridDensity*         = WM_USER + 12
  idMsgGridSnap*            = WM_USER + 13
  idMsgGridDynamic*         = WM_USER + 14
  idMsgGridBaseSync*        = WM_USER + 15
  idMsgGridVisible*         = WM_USER + 16
  idMsgGridDots*            = WM_USER + 17
  idMsgGridLines*           = WM_USER + 18
  
  # Frames
  idMsgGridCtrlFrameClosing* = WM_USER + 19

  
  # Random thread stuff
  ALG_NO_INIT_BMP*  = 0
  ALG_INIT_BMP*     = 10