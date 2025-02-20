import winim/inc/[windef,winuser]

const
    USER_SIZE*       = WM_APP + 1
    USER_MOUSE_MOVE* = WM_APP + 2
    USER_SLIDER*     = WM_APP + 3
    USER_PAINT_DONE* = WM_APP + 4
    USER_ALG_UPDATE* = WM_APP + 5

#echo $USER_SIZE
#echo $USER_MOUSE_MOVE