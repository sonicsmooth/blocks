from winim/inc/winuser import WM_APP

const
  USER_MOUSE_MOVE* = WM_APP + 1
  USER_SIZE*       = WM_APP + 2
  USER_PAINT_DONE* = WM_APP + 3
  USER_SLIDER*     = WM_APP + 4
  USER_ALG_UPDATE* = WM_APP + 5

  ALG_NO_INIT_BMP*  = 0
  ALG_INIT_BMP*     = 1