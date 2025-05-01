
import std/[bitops, strformat]
from std/random import rand
import sugar
from wnim/private/wtypes import wColor
import wnim/private/consts/wColors
from sdl2 import Color

type
  ColorFormat = enum RGBA, ARGB, BGRA, ABGR
  ColorU32* = distinct uint32
  SomeColor = Color|ColorU32|wColor|SomeInteger

const
  ColorFmt = 
    when defined(argb):
      ARGB
    else:
      RGBA


when ColorFmt == ARGB:
  const
    ASH = 24
    RSH = 16
    GSH =  8
    BSH =  0
elif ColorFmt == RGBA:
  const
    RSH = 24
    GSH = 16
    BSH =  8
    ASH =  0
elif ColorFmt == BGRA:
  const
    BSH = 24
    GSH = 16
    RSH =  8
    ASH =  0
elif ColorFmt == ABGR:
  const
    ASH = 24
    BSH = 16
    GSH =  8
    RSH =  0

const
  rmask* = 0xff.shl(RSH).uint32
  gmask* = 0xff.shl(GSH).uint32
  bmask* = 0xff.shl(BSH).uint32
  amask* = 0xff.shl(ASH).uint32

proc `$`*(color: ColorU32): string =
  fmt"{uint32(color):08x}"
proc `==`*(c1: ColorU32|uint32, c2: ColorU32|uint32): bool =
  c1.uint32 == c2.uint32

# Color tuple uses named fields
template red*  (color: Color): uint8 = color.r
template green*(color: Color): uint8 = color.g
template blue* (color: Color): uint8 = color.b
template alpha*(color: Color): uint8 = color.a

# ColorU32 is one of RGBA, ARGB, BGRA, ABGR
template red*  (color: ColorU32): uint8 = color.uint32.shr(RSH).uint8
template green*(color: ColorU32): uint8 = color.uint32.shr(GSH).uint8
template blue* (color: ColorU32): uint8 = color.uint32.shr(BSH).uint8
template alpha*(color: ColorU32): uint8 = color.uint32.shr(ASH).uint8

# SomeInteger is assumed to be RGB only; use opaque alpha
template red*  (color: SomeInteger): uint8 = color.uint32.shr(16).uint8
template green*(color: SomeInteger): uint8 = color.uint32.shr( 8).uint8
template blue* (color: SomeInteger): uint8 = color.uint32.shr( 0).uint8
template alpha*(color: SomeInteger): uint8 = 0xff'u8

# wColor is known to be BGR only; use opaque alpha
template red*  (color: wColor): uint8 = color.shr( 0).uint8
template green*(color: wColor): uint8 = color.shr( 8).uint8
template blue* (color: wColor): uint8 = color.shr(16).uint8
template alpha*(color: wColor): uint8 = 0xff'u8

proc assembleBits(r,g,b,a: uint32): ColorU32 {.inline.} =
  when ColorFmt == RGBA: bitor(r.shl(24), g.shl(16), b.shl(8), a).ColorU32
  elif ColorFmt == BGRA: bitor(b.shl(24), g.shl(16), r.shl(8), a).ColorU32
  elif ColorFmt == ARGB: bitor(a.shl(24), r.shl(16), g.shl(8), b).ColorU32
  elif ColorFmt == ABGR: bitor(a.shl(24), b.shl(16), g.shl(8), r).ColorU32


proc toColorU32*(color: SomeColor, a: SomeInteger): ColorU32 {.inline.} =
  # Convert SomeColor to ColorU32 using a for alpha
  # Use this to change alpha in Color or ColorU32
  let
    r: uint32 = color.red
    g: uint32 = color.green
    b: uint32 = color.blue
    a: uint32 = a.uint32
  assembleBits(r,g,b,a)

proc toColorU32*(color: SomeColor): ColorU32 {.inline.} =
  # Convert SomeColor to ColorU32.
  let
    r: uint32 = color.red
    g: uint32 = color.green
    b: uint32 = color.blue
    a: uint32 = color.alpha
  assembleBits(r,g,b,a)


template toColor*(color: SomeColor, alpha: range[0..255]): Color =
  (r: color.red, g: color.green, b: color.blue, a: alpha.uint8).Color

template toColor*(color: SomeColor  ): Color =
  block:
    when typeof(color) is Color:
      color
    else:
      let alpha = if color.alpha > 0: color.alpha
                  else: 255'u8
      (r: color.red, g: color.green, b: color.blue, a: alpha).Color

proc colordiv*(color: ColorU32, num: SomeInteger): ColorU32 =
  let
    r = color.red.uint32   div num.uint32
    g = color.green.uint32 div num.uint32
    b = color.blue.uint32  div num.uint32
    a = color.alpha.uint32
  assembleBits(r,g,b,a)

proc colordiv*(color: Color, num: SomeInteger): Color =
  let
    r = color.red   div num.uint8
    g = color.green div num.uint8
    b = color.blue  div num.uint8
    a = color.alpha.uint8
  (r: color.red, g: color.green, b: color.blue, a: alpha).Color

proc colordiv*(color: wColor, num: SomeInteger): wColor =
  let
    r = (color.red.uint32   div num.uint32).shl( 0)
    g = (color.green.uint32 div num.uint32).shl( 8)
    b = (color.blue.uint32  div num.uint32).shl(16)
    a = color.alpha.uint32.shl(24)
  bitor(r,g,b,a).wColor



proc randColor*(): ColorU32 = 
  let
    r = (rand(255) shl RSH)
    g = (rand(255) shl GSH)
    b = (rand(255) shl BSH)
    a = (     200  shl ASH)
  bitor(r,g,b,a).ColorU32 # rrggbbaa

const
  colAliceBlue*            = toColorU32(0xF0F8FF'u32) #F0F8FF
  colAntiqueWhite*         = toColorU32(0xFAEBD7'u32) #FAEBD7
  colAqua*                 = toColorU32(0x00FFFF'u32) #00FFFF
  colAquamarine*           = toColorU32(0x7FFFD4'u32) #7FFFD4
  colAzure*                = toColorU32(0xF0FFFF'u32) #F0FFFF
  colBeige*                = toColorU32(0xF5F5DC'u32) #F5F5DC
  colBisque*               = toColorU32(0xFFE4C4'u32) #FFE4C4
  colBlack*                = toColorU32(0x000000'u32) #000000
  colBlanchedAlmond*       = toColorU32(0xFFEBCD'u32) #FFEBCD
  colBlue*                 = toColorU32(0x0000FF'u32) #0000FF
  colBlueViolet*           = toColorU32(0x8A2BE2'u32) #8A2BE2
  colBrown*                = toColorU32(0xA52A2A'u32) #A52A2A
  colBurlyWood*            = toColorU32(0xDEB887'u32) #DEB887
  colCadetBlue*            = toColorU32(0x5F9EA0'u32) #5F9EA0
  colChartreuse*           = toColorU32(0x7FFF00'u32) #7FFF00
  colChocolate*            = toColorU32(0xD2691E'u32) #D2691E
  colCoral*                = toColorU32(0xFF7F50'u32) #FF7F50
  colCornflowerBlue*       = toColorU32(0x6495ED'u32) #6495ED
  colCornsilk*             = toColorU32(0xFFF8DC'u32) #FFF8DC
  colCrimson*              = toColorU32(0xDC143C'u32) #DC143C
  colCyan*                 = toColorU32(0x00FFFF'u32) #00FFFF
  colDarkBlue*             = toColorU32(0x00008B'u32) #00008B
  colDarkCyan*             = toColorU32(0x008B8B'u32) #008B8B
  colDarkGoldenRod*        = toColorU32(0xB8860B'u32) #B8860B
  colDarkGray*             = toColorU32(0xA9A9A9'u32) #A9A9A9
  colDarkGreen*            = toColorU32(0x006400'u32) #006400
  colDarkGrey*             = toColorU32(0xA9A9A9'u32) #A9A9A9
  colDarkKhaki*            = toColorU32(0xBDB76B'u32) #BDB76B
  colDarkMagenta*          = toColorU32(0x8B008B'u32) #8B008B
  colDarkOliveGreen*       = toColorU32(0x556B2F'u32) #556B2F
  colDarkorange*           = toColorU32(0xFF8C00'u32) #FF8C00
  colDarkOrchid*           = toColorU32(0x9932CC'u32) #9932CC
  colDarkRed*              = toColorU32(0x8B0000'u32) #8B0000
  colDarkSalmon*           = toColorU32(0xE9967A'u32) #E9967A
  colDarkSeaGreen*         = toColorU32(0x8FBC8F'u32) #8FBC8F
  colDarkSlateBlue*        = toColorU32(0x483D8B'u32) #483D8B
  colDarkSlateGray*        = toColorU32(0x2F4F4F'u32) #2F4F4F
  colDarkSlateGrey*        = toColorU32(0x2F4F4F'u32) #2F4F4F
  colDarkTurquoise*        = toColorU32(0x00CED1'u32) #00CED1
  colDarkViolet*           = toColorU32(0x9400D3'u32) #9400D3
  colDeepPink*             = toColorU32(0xFF1493'u32) #FF1493
  colDeepSkyBlue*          = toColorU32(0x00BFFF'u32) #00BFFF
  colDimGray*              = toColorU32(0x696969'u32) #696969
  colDimGrey*              = toColorU32(0x696969'u32) #696969
  colDodgerBlue*           = toColorU32(0x1E90FF'u32) #1E90FF
  colFireBrick*            = toColorU32(0xB22222'u32) #B22222
  colFloralWhite*          = toColorU32(0xFFFAF0'u32) #FFFAF0
  colForestGreen*          = toColorU32(0x228B22'u32) #228B22
  colFuchsia*              = toColorU32(0xFF00FF'u32) #FF00FF
  colGainsboro*            = toColorU32(0xDCDCDC'u32) #DCDCDC
  colGhostWhite*           = toColorU32(0xF8F8FF'u32) #F8F8FF
  colGold*                 = toColorU32(0xFFD700'u32) #FFD700
  colGoldenRod*            = toColorU32(0xDAA520'u32) #DAA520
  colGray*                 = toColorU32(0x808080'u32) #808080
  colGreen*                = toColorU32(0x008000'u32) #008000
  colGreenYellow*          = toColorU32(0xADFF2F'u32) #ADFF2F
  colGrey*                 = toColorU32(0x808080'u32) #808080
  colHoneyDew*             = toColorU32(0xF0FFF0'u32) #F0FFF0
  colHotPink*              = toColorU32(0xFF69B4'u32) #FF69B4
  colIndianRed*            = toColorU32(0xCD5C5C'u32) #CD5C5C
  colIndigo*               = toColorU32(0x4B0082'u32) #4B0082
  colIvory*                = toColorU32(0xFFFFF0'u32) #FFFFF0
  colKhaki*                = toColorU32(0xF0E68C'u32) #F0E68C
  colLavender*             = toColorU32(0xE6E6FA'u32) #E6E6FA
  colLavenderBlush*        = toColorU32(0xFFF0F5'u32) #FFF0F5
  colLawnGreen*            = toColorU32(0x7CFC00'u32) #7CFC00
  colLemonChiffon*         = toColorU32(0xFFFACD'u32) #FFFACD
  colLightBlue*            = toColorU32(0xADD8E6'u32) #ADD8E6
  colLightCoral*           = toColorU32(0xF08080'u32) #F08080
  colLightCyan*            = toColorU32(0xE0FFFF'u32) #E0FFFF
  colLightGoldenRodYellow* = toColorU32(0xFAFAD2'u32) #FAFAD2
  colLightGray*            = toColorU32(0xD3D3D3'u32) #D3D3D3
  colLightGreen*           = toColorU32(0x90EE90'u32) #90EE90
  colLightGrey*            = toColorU32(0xD3D3D3'u32) #D3D3D3
  colLightPink*            = toColorU32(0xFFB6C1'u32) #FFB6C1
  colLightSalmon*          = toColorU32(0xFFA07A'u32) #FFA07A
  colLightSeaGreen*        = toColorU32(0x20B2AA'u32) #20B2AA
  colLightSkyBlue*         = toColorU32(0x87CEFA'u32) #87CEFA
  colLightSlateGray*       = toColorU32(0x778899'u32) #778899
  colLightSlateGrey*       = toColorU32(0x778899'u32) #778899
  colLightSteelBlue*       = toColorU32(0xB0C4DE'u32) #B0C4DE
  colLightYellow*          = toColorU32(0xFFFFE0'u32) #FFFFE0
  colLime*                 = toColorU32(0x00FF00'u32) #00FF00
  colLimeGreen*            = toColorU32(0x32CD32'u32) #32CD32
  colLinen*                = toColorU32(0xFAF0E6'u32) #FAF0E6
  colMagenta*              = toColorU32(0xFF00FF'u32) #FF00FF
  colMaroon*               = toColorU32(0x800000'u32) #800000
  colMediumAquaMarine*     = toColorU32(0x66CDAA'u32) #66CDAA
  colMediumBlue*           = toColorU32(0x0000CD'u32) #0000CD
  colMediumOrchid*         = toColorU32(0xBA55D3'u32) #BA55D3
  colMediumPurple*         = toColorU32(0x9370DB'u32) #9370DB
  colMediumSeaGreen*       = toColorU32(0x3CB371'u32) #3CB371
  colMediumSlateBlue*      = toColorU32(0x7B68EE'u32) #7B68EE
  colMediumSpringGreen*    = toColorU32(0x00FA9A'u32) #00FA9A
  colMediumTurquoise*      = toColorU32(0x48D1CC'u32) #48D1CC
  colMediumVioletRed*      = toColorU32(0xC71585'u32) #C71585
  colMidnightBlue*         = toColorU32(0x191970'u32) #191970
  colMintCream*            = toColorU32(0xF5FFFA'u32) #F5FFFA
  colMistyRose*            = toColorU32(0xFFE4E1'u32) #FFE4E1
  colMoccasin*             = toColorU32(0xFFE4B5'u32) #FFE4B5
  colNavajoWhite*          = toColorU32(0xFFDEAD'u32) #FFDEAD
  colNavy*                 = toColorU32(0x000080'u32) #000080
  colOldLace*              = toColorU32(0xFDF5E6'u32) #FDF5E6
  colOlive*                = toColorU32(0x808000'u32) #808000
  colOliveDrab*            = toColorU32(0x6B8E23'u32) #6B8E23
  colOrange*               = toColorU32(0xFFA500'u32) #FFA500
  colOrangeRed*            = toColorU32(0xFF4500'u32) #FF4500
  colOrchid*               = toColorU32(0xDA70D6'u32) #DA70D6
  colPaleGoldenRod*        = toColorU32(0xEEE8AA'u32) #EEE8AA
  colPaleGreen*            = toColorU32(0x98FB98'u32) #98FB98
  colPaleTurquoise*        = toColorU32(0xAFEEEE'u32) #AFEEEE
  colPaleVioletRed*        = toColorU32(0xDB7093'u32) #DB7093
  colPapayaWhip*           = toColorU32(0xFFEFD5'u32) #FFEFD5
  colPeachPuff*            = toColorU32(0xFFDAB9'u32) #FFDAB9
  colPeru*                 = toColorU32(0xCD853F'u32) #CD853F
  colPink*                 = toColorU32(0xFFC0CB'u32) #FFC0CB
  colPlum*                 = toColorU32(0xDDA0DD'u32) #DDA0DD
  colPowderBlue*           = toColorU32(0xB0E0E6'u32) #B0E0E6
  colPurple*               = toColorU32(0x800080'u32) #800080
  colRebeccaPurple*        = toColorU32(0x663399'u32) #663399
  colRed*                  = toColorU32(0xFF0000'u32) #FF0000
  colRosyBrown*            = toColorU32(0xBC8F8F'u32) #BC8F8F
  colRoyalBlue*            = toColorU32(0x4169E1'u32) #4169E1
  colSaddleBrown*          = toColorU32(0x8B4513'u32) #8B4513
  colSalmon*               = toColorU32(0xFA8072'u32) #FA8072
  colSandyBrown*           = toColorU32(0xF4A460'u32) #F4A460
  colSeaGreen*             = toColorU32(0x2E8B57'u32) #2E8B57
  colSeaShell*             = toColorU32(0xFFF5EE'u32) #FFF5EE
  colSienna*               = toColorU32(0xA0522D'u32) #A0522D
  colSilver*               = toColorU32(0xC0C0C0'u32) #C0C0C0
  colSkyBlue*              = toColorU32(0x87CEEB'u32) #87CEEB
  colSlateBlue*            = toColorU32(0x6A5ACD'u32) #6A5ACD
  colSlateGray*            = toColorU32(0x708090'u32) #708090
  colSlateGrey*            = toColorU32(0x708090'u32) #708090
  colSnow*                 = toColorU32(0xFFFAFA'u32) #FFFAFA
  colSpringGreen*          = toColorU32(0x00FF7F'u32) #00FF7F
  colSteelBlue*            = toColorU32(0x4682B4'u32) #4682B4
  colTan*                  = toColorU32(0xD2B48C'u32) #D2B48C
  colTeal*                 = toColorU32(0x008080'u32) #008080
  colThistle*              = toColorU32(0xD8BFD8'u32) #D8BFD8
  colTomato*               = toColorU32(0xFF6347'u32) #FF6347
  colTurquoise*            = toColorU32(0x40E0D0'u32) #40E0D0
  colViolet*               = toColorU32(0xEE82EE'u32) #EE82EE
  colWheat*                = toColorU32(0xF5DEB3'u32) #F5DEB3
  colWhite*                = toColorU32(0xFFFFFF'u32) #FFFFFF
  colWhiteSmoke*           = toColorU32(0xF5F5F5'u32) #F5F5F5
  colYellow*               = toColorU32(0xFFFF00'u32) #FFFF00
  colYellowGreen*          = toColorU32(0x9ACD32'u32) #9ACD32

when isMainModule:
  import sugar
  echo "Main Module"
  let sdlRed  : sdl2.Color = (r: 255, g: 0,   b: 0,   a: 127)
  let sdlGreen: sdl2.Color = (r: 0,   g: 255, b: 0,   a: 127)
  let sdlBlue : sdl2.Color = (r: 0,   g:0,    b: 255, a: 127)

  dump ColorFmt
  echo "Testing assertions"
  assert sdlRed.toColorU32.red     == 0xff'u8
  assert sdlRed.toColorU32.green   == 0x00'u8
  assert sdlRed.toColorU32.blue    == 0x00'u8
  assert sdlRed.toColorU32.alpha   == 0x7f'u8
  assert sdlGreen.toColorU32.red   == 0x00'u8
  assert sdlGreen.toColorU32.green == 0xff'u8
  assert sdlGreen.toColorU32.blue  == 0x00'u8
  assert sdlGreen.toColorU32.alpha == 0x7f'u8
  assert sdlBlue.toColorU32.red    == 0x00'u8
  assert sdlBlue.toColorU32.green  == 0x00'u8
  assert sdlBlue.toColorU32.blue   == 0xff'u8
  assert sdlBlue.toColorU32.alpha  == 0x7f'u8
  assert wRed.red                  == 0xff'u8
  assert wRed.green                == 0x00'u8
  assert wRed.blue                 == 0x00'u8
  assert wRed.alpha                == 0xff'u8
  assert wGreen.red                == 0x00'u8
  assert wGreen.green              == 0xff'u8
  assert wGreen.blue               == 0x00'u8
  assert wGreen.alpha              == 0xff'u8
  assert wBlue.red                 == 0x00'u8
  assert wBlue.green               == 0x00'u8
  assert wBlue.blue                == 0xff'u8
  assert wBlue.alpha               == 0xff'u8
  assert 0xff0000.toColor          == (r: 255'u8, g:   0'u8, b:   0'u8, a: 255'u8).Color
  assert 0x00ff00.toColor          == (r:   0'u8, g: 255'u8, b:   0'u8, a: 255'u8).Color
  assert 0x0000ff.toColor          == (r:   0'u8, g:   0'u8, b: 255'u8, a: 255'u8).Color
  assert sdlRed.toColor            == (r: 255'u8, g:   0'u8, b:   0'u8, a: 127'u8).Color
  assert sdlGreen.toColor          == (r:   0'u8, g: 255'u8, b:   0'u8, a: 127'u8).Color
  assert sdlBlue.toColor           == (r:   0'u8, g:   0'u8, b: 255'u8, a: 127'u8).Color
  assert wRed.toColor              == (r: 255'u8, g:   0'u8, b:   0'u8, a: 255'u8).Color
  assert wGreen.toColor            == (r:   0'u8, g: 255'u8, b:   0'u8, a: 255'u8).Color
  assert wBlue.toColor             == (r:   0'u8, g:   0'u8, b: 255'u8, a: 255'u8).Color
  assert colRed.toColor            == (r: 255'u8, g:   0'u8, b:   0'u8, a: 255'u8).Color
  assert colLime.toColor           == (r:   0'u8, g: 255'u8, b:   0'u8, a: 255'u8).Color
  assert colBlue.toColor           == (r:   0'u8, g:   0'u8, b: 255'u8, a: 255'u8).Color

  when ColorFmt == RGBA:
    assert sdlRed.toColorU32                   == 0xff00007f'u32
    assert sdlGreen.toColorU32                 == 0x00ff007f'u32
    assert sdlBlue.toColorU32                  == 0x0000ff7f'u32
    assert wRed.toColorU32                     == 0xff0000ff'u32
    assert wGreen.toColorU32                   == 0x00ff00ff'u32
    assert wBlue.toColorU32                    == 0x0000ffff'u32
    assert colRed.toColorU32                   == 0xff0000ff'u32
    assert colLime.toColorU32                  == 0x00ff00ff'u32
    assert colBlue.toColorU32                  == 0x0000ffff'u32
    assert colRed                              == 0xff0000ff'u32
    assert colLime                             == 0x00ff00ff'u32
    assert colBlue                             == 0x0000ffff'u32
    assert wRed.toColorU32(127)                == 0xff00007f'u32
    assert wGreen.toColorU32(127)              == 0x00ff007f'u32
    assert wBlue.toColorU32(127)               == 0x0000ff7f'u32
    assert colRed.toColorU32(127)              == 0xff00007f'u32
    assert colLime.toColorU32(127)             == 0x00ff007f'u32
    assert colBlue.toColorU32(127)             == 0x0000ff7f'u32
    assert colRed.toColorU32.div(2)            == 0x7f0000ff'u32
    assert colLime.toColorU32.div(2)           == 0x007f00ff'u32
    assert colBlue.toColorU32.div(2)           == 0x00007fff'u32
    assert colRed.toColorU32(127).div(2)       == 0x7f00007f'u32
    assert colLime.toColorU32(127).div(2)      == 0x007f007f'u32
    assert colBlue.toColorU32(127).div(2)      == 0x00007f7f'u32

    assert 0xff0000.toColorU32                 == 0xff0000ff'u32 
    assert 0x00ff00.toColorU32                 == 0x00ff00ff'u32 
    assert 0x0000ff.toColorU32                 == 0x0000ffff'u32 
    assert 0xff0000.toColorU32(127)            == 0xff00007f'u32
    assert 0x00ff00.toColorU32(127)            == 0x00ff007f'u32
    assert 0x0000ff.toColorU32(127)            == 0x0000ff7f'u32
    assert 0xabcdefaa_55ff0000.toColorU32      == 0xff0000ff'u32 
    assert 0xabcdefaa_5500ff00.toColorU32      == 0x00ff00ff'u32 
    assert 0xabcdefaa_550000ff.toColorU32      == 0x0000ffff'u32 
    assert 0xabcdefaa_55ff0000.toColorU32(127) == 0xff00007f'u32
    assert 0xabcdefaa_5500ff00.toColorU32(127) == 0x00ff007f'u32
    assert 0xabcdefaa_550000ff.toColorU32(127) == 0x0000ff7f'u32



  elif ColorFmt == ARGB:
    assert sdlRed.toColorU32                   == 0x7fff0000'u32
    assert sdlGreen.toColorU32                 == 0x7f00ff00'u32
    assert sdlBlue.toColorU32                  == 0x7f0000ff'u32
    assert wRed.toColorU32                     == 0xffff0000'u32
    assert wGreen.toColorU32                   == 0xff00ff00'u32
    assert wBlue.toColorU32                    == 0xff0000ff'u32
    assert colRed.toColorU32                   == 0xffff0000'u32
    assert colLime.toColorU32                  == 0xff00ff00'u32
    assert colBlue.toColorU32                  == 0xff0000ff'u32
    assert colRed                              == 0xffff0000'u32
    assert colLime                             == 0xff00ff00'u32
    assert colBlue                             == 0xff0000ff'u32
    assert wRed.toColorU32(127)                == 0x7fff0000'u32
    assert wGreen.toColorU32(127)              == 0x7f00ff00'u32
    assert wBlue.toColorU32(127)               == 0x7f0000ff'u32
    assert colRed.toColorU32(127)              == 0x7fff0000'u32
    assert colLime.toColorU32(127)             == 0x7f00ff00'u32
    assert colBlue.toColorU32(127)             == 0x7f0000ff'u32
    assert colRed.toColorU32.div(2)            == 0xff7f0000'u32
    assert colLime.toColorU32.div(2)           == 0xff007f00'u32
    assert colBlue.toColorU32.div(2)           == 0xff00007f'u32
    assert colRed.toColorU32(127).div(2)       == 0x7f7f0000'u32
    assert colLime.toColorU32(127).div(2)      == 0x7f007f00'u32
    assert colBlue.toColorU32(127).div(2)      == 0x7f00007f'u32
    assert 0xff0000.toColorU32                 == 0xffff0000'u32
    assert 0x00ff00.toColorU32                 == 0xff00ff00'u32
    assert 0x0000ff.toColorU32                 == 0xff0000ff'u32
    assert 0xff0000.toColorU32(127)            == 0x7fff0000'u32
    assert 0x00ff00.toColorU32(127)            == 0x7f00ff00'u32
    assert 0x0000ff.toColorU32(127)            == 0x7f0000ff'u32
    assert 0xabcdefaa_55ff0000.toColorU32      == 0xffff0000'u32
    assert 0xabcdefaa_5500ff00.toColorU32      == 0xff00ff00'u32
    assert 0xabcdefaa_550000ff.toColorU32      == 0xff0000ff'u32
    assert 0xabcdefaa_55ff0000.toColorU32(127) == 0x7fff0000'u32
    assert 0xabcdefaa_5500ff00.toColorU32(127) == 0x7f00ff00'u32
    assert 0xabcdefaa_550000ff.toColorU32(127) == 0x7f0000ff'u32


echo "Done"