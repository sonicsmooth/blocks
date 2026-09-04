from winim/inc/winuser import WM_USER

# These are constant values that go across 
# threads or from one frame to another.
# a blaSend is sent from the dialog in question
# a blaRecv is received by the dialog in question

type MsgId* = enum
  woMouseMove, woSize, woSlider, woAlgUpdate,
  woGridZoom, woGridSizeX, woGridRequestX, woGridSizeY,
  woGridRequestY, woGridDivisionsSelect, woGridDivisionsValue,
  woGridDivisionsReset, woGridDensity, woGridSnap, woGridDynamic,
  woGridBaseSync, woGridVisible, woGridDots, woGridLines,
  woGridCtrlFrameClosing, 

  woPlcDownLeft, woPlcDown, woPlcDownRight, woPlcLeft,
  woPlcRight, woPlcUpLeft, woPlcUndo, woPlcUp,
  woPlcUpRight, woPlcDrawRegionEnd, woPlcDrawRegionStart,
  woPlcFrameClosing, woPlcRandomAll, woPlcRandomPos,
  woPlcSelectedRecv, woPlcTest, woPlcTxtHRecv, woPlcTxtHSend,
  woPLcTxtQtyRecv, woPlcTxtQtySend, woPlcTxtTempRecv,
  woPlcTxtWRecv, woPlcTxtWSend, woPlcTxtXRecv, woPlcTxtXSend,
  woPlcTxtyRecv, woPlcTxtYSend

  kCmpBtnTest, kCmpBtnRandAll, kCmpBtnRandPos,
  kCmpCompactReq

    
const
  # Get rid of these
  idMsgMouseMove*       = WM_USER + ord(woMouseMove)
  idMsgSize*            = WM_USER + ord(woSize)
  idMsgSlider*          = WM_USER + ord(woSlider)
  idMsgAlgUpdate*       = WM_USER + ord(woAlgUpdate)
  
  # Grid Control Frame
  idGCFZoom*            = WM_USER + ord(woGridZoom)
  idGCFSizeX*           = WM_USER + ord(woGridSizeX)
  idGCFRequestX*        = WM_USER + ord(woGridRequestX)
  idGCFSizeY*           = WM_USER + ord(woGridSizeY)
  idGCFRequestY*        = WM_USER + ord(woGridRequestY)
  idGCFDivisionsSelect* = WM_USER + ord(woGridDivisionsSelect)
  idGCFDivisionsValue*  = WM_USER + ord(woGridDivisionsValue)
  idGCFDivisionsReset*  = WM_USER + ord(woGridDivisionsReset)
  idGCFDensity*         = WM_USER + ord(woGridDensity)
  idGCFSnap*            = WM_USER + ord(woGridSnap)
  idGCFDynamic*         = WM_USER + ord(woGridDynamic)
  idGCFBaseSync*        = WM_USER + ord(woGridBaseSync)
  idGCFVisible*         = WM_USER + ord(woGridVisible)
  idGCFDots*            = WM_USER + ord(woGridDots)
  idGCFLines*           = WM_USER + ord(woGridLines)
  idGCFClosing*         = WM_USER + ord(woGridCtrlFrameClosing)
  
  # Placement Frame
  idPlcDownLeft*        = WM_USER + ord(woPlcDownLeft)
  idPlcDown*            = WM_USER + ord(woPlcDown)
  idPlcDownRight*       = WM_USER + ord(woPlcDownRight)
  idPlcLeft*            = WM_USER + ord(woPlcLeft)
  idPlcRight*           = WM_USER + ord(woPlcRight)
  idPlcUpLeft*          = WM_USER + ord(woPlcUpLeft)
  idPlcUndo*            = WM_USER + ord(woPlcUndo)
  idPlcUp*              = WM_USER + ord(woPlcUp)
  idPlcUpRight*         = WM_USER + ord(woPlcUpRight)
  idPlcDrawRegionEnd*   = WM_USER + ord(woPlcDrawRegionEnd)
  idPlcDrawRegionStart* = WM_USER + ord(woPlcDrawRegionStart)
  idPlcFrameClosing*    = WM_USER + ord(woPlcFrameClosing)
  idPlcRandomAll*       = WM_USER + ord(woPlcRandomAll)
  idPlcRandomPos*       = WM_USER + ord(woPlcRandomPos)
  idPlcSelectedRecv*    = WM_USER + ord(woPlcSelectedRecv)
  idPlcTest*            = WM_USER + ord(woPlcTest)
  idPLcTxtQtyRecv*      = WM_USER + ord(woPLCTxtQtyRecv)
  idPlcTxtQtySend*      = WM_USER + ord(woPlcTxtQtySend)
  idPlcTxtXRecv*        = WM_USER + ord(woPlcTxtXRecv)
  idPlcTxtXSend*        = WM_USER + ord(woPlcTxtXSend)
  idPlcTxtyRecv*        = WM_USER + ord(woPlcTxtyRecv)
  idPlcTxtYSend*        = WM_USER + ord(woPlcTxtYSend)
  idPlcTxtWRecv*        = WM_USER + ord(woPlcTxtWRecv)
  idPlcTxtWSend*        = WM_USER + ord(woPlcTxtWSend)
  idPlcTxtHRecv*        = WM_USER + ord(woPlcTxtHRecv)
  idPlcTxtHSend*        = WM_USER + ord(woPlcTxtHSend)
  idPlcTxtTempRecv*     = WM_USER + ord(woPlcTxtTempRecv)



  
  # Random thread stuff
  ALG_NO_INIT_BMP*  = 0
  ALG_INIT_BMP*     = 10