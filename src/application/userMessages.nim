from winim/inc/winuser import WM_USER

# These are constant values that go across 
# threads or from one frame to another.
# a blaSend is sent from the dialog in question
# a blaRecv is received by the dialog in question

# There are a few message and ID types
# IDs for widgets
# IDs for messages used in SendMessage (received by a Window)
# Keys for the pubsub mechanism

type
  # Platform (UI)-specific message IDs for sending messages to windows
  MsgId* = enum
    woMouseMove, woSize, woSlider, woAlgUpdate,
    woGridZoom, woGridSizeX, woGridRequestX, woGridSizeY,
    woGridRequestY, woGridDivisionsSelect, woGridDivisionsValue,
    woGridDivisionsReset, woGridDensity, woGridSnap, woGridDynamic,
    woGridBaseSync, woGridVisible, woGridDots, woGridLines,
    woGridCtrlFrameClosing, 

    woPlcFrameClosing, 

  # Domain-specific keys (topics) for the pubsub mechanism
  CompactDlgPubSubTopic* = enum
    Test, RandAll, RandPos, Undo, Done, # Signals
    Qty, Selected, # Integers
    RegionX, RegionY, RegionW, RegionH, CurrentTemp, # Floats
    CompactReq # CompactRequest
  SignalTopic* = range[Test..Done]
    
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
  
  # # Placement Frame
  idPlcFrameClosing*    = WM_USER + ord(woPlcFrameClosing)


  
  # Random thread stuff
  ALG_NO_INIT_BMP*  = 0
  ALG_INIT_BMP*     = 10