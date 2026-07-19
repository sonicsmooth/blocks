
from std/random import rand
from std/math import round
import std/tables

type
  Color* = object
    r*: uint8
    g*: uint8
    b*: uint8
    a*: uint8

proc toColor*(val: uint32): Color =
  # Assume val is only RGB.
  result.r = uint8((val shr 16) and 0xff)
  result.g = uint8((val shr  8) and 0xff)
  result.b = uint8((val shr  0) and 0xff)
  result.a = uint8(255)

proc toColor*(val: uint32, alpha: uint8): Color =
  # Assume val is only RGB.
  result.r = uint8((val shr 16) and 0xff)
  result.g = uint8((val shr  8) and 0xff)
  result.b = uint8((val shr  0) and 0xff)
  result.a = alpha

proc randColor*(): Color =
  result.r = rand(255).uint8
  result.g = rand(255).uint8
  result.b = rand(255).uint8
  result.a = 200'u8

proc toU32_RGB*(val: Color): uint32 =
  let
    r: uint32 = val.r.uint32 shl 16
    g: uint32 = val.g.uint32 shl  8
    b: uint32 = val.b.uint32 shl  0
  r or g or b

proc toU32_RGBA*(val: Color): uint32 =
  let
    r: uint32 = val.r.uint32 shl 24
    g: uint32 = val.g.uint32 shl 16
    b: uint32 = val.b.uint32 shl  8
    a: uint32 = val.a.uint32 shl  0
  r or g or b or a

proc `*`*(val: Color, scale: float): Color =
  result.r = (val.r.float * scale).clamp(0, 255).round.uint8
  result.g = (val.g.float * scale).clamp(0, 255).round.uint8
  result.b = (val.b.float * scale).clamp(0, 255).round.uint8
  result.a = val.a

proc `$`*(val: Color): string =
  result = "(r: " & $val.r.int & ", " &
           " g: " & $val.g.int & ", " &
           " b: " & $val.b.int & ", " &
           " g: " & $val.a.int & ")"

const
  AliceBlue*            = toColor(0xF0F8FF'u32) #F0F8FF
  AntiqueWhite*         = toColor(0xFAEBD7'u32) #FAEBD7
  Aqua*                 = toColor(0x00FFFF'u32) #00FFFF
  Aquamarine*           = toColor(0x7FFFD4'u32) #7FFFD4
  Azure*                = toColor(0xF0FFFF'u32) #F0FFFF
  Beige*                = toColor(0xF5F5DC'u32) #F5F5DC
  Bisque*               = toColor(0xFFE4C4'u32) #FFE4C4
  Black*                = toColor(0x000000'u32) #000000
  BlanchedAlmond*       = toColor(0xFFEBCD'u32) #FFEBCD
  Blue*                 = toColor(0x0000FF'u32) #0000FF
  BlueViolet*           = toColor(0x8A2BE2'u32) #8A2BE2
  Brown*                = toColor(0xA52A2A'u32) #A52A2A
  BurlyWood*            = toColor(0xDEB887'u32) #DEB887
  CadetBlue*            = toColor(0x5F9EA0'u32) #5F9EA0
  Chartreuse*           = toColor(0x7FFF00'u32) #7FFF00
  Chocolate*            = toColor(0xD2691E'u32) #D2691E
  Coral*                = toColor(0xFF7F50'u32) #FF7F50
  CornflowerBlue*       = toColor(0x6495ED'u32) #6495ED
  Cornsilk*             = toColor(0xFFF8DC'u32) #FFF8DC
  Crimson*              = toColor(0xDC143C'u32) #DC143C
  Cyan*                 = toColor(0x00FFFF'u32) #00FFFF
  DarkBlue*             = toColor(0x00008B'u32) #00008B
  DarkCyan*             = toColor(0x008B8B'u32) #008B8B
  DarkGoldenRod*        = toColor(0xB8860B'u32) #B8860B
  DarkGray*             = toColor(0xA9A9A9'u32) #A9A9A9
  DarkGreen*            = toColor(0x006400'u32) #006400
  DarkGrey*             = toColor(0xA9A9A9'u32) #A9A9A9
  DarkKhaki*            = toColor(0xBDB76B'u32) #BDB76B
  DarkMagenta*          = toColor(0x8B008B'u32) #8B008B
  DarkOliveGreen*       = toColor(0x556B2F'u32) #556B2F
  Darkorange*           = toColor(0xFF8C00'u32) #FF8C00
  DarkOrchid*           = toColor(0x9932CC'u32) #9932CC
  DarkRed*              = toColor(0x8B0000'u32) #8B0000
  DarkSalmon*           = toColor(0xE9967A'u32) #E9967A
  DarkSeaGreen*         = toColor(0x8FBC8F'u32) #8FBC8F
  DarkSlateBlue*        = toColor(0x483D8B'u32) #483D8B
  DarkSlateGray*        = toColor(0x2F4F4F'u32) #2F4F4F
  DarkSlateGrey*        = toColor(0x2F4F4F'u32) #2F4F4F
  DarkTurquoise*        = toColor(0x00CED1'u32) #00CED1
  DarkViolet*           = toColor(0x9400D3'u32) #9400D3
  DeepPink*             = toColor(0xFF1493'u32) #FF1493
  DeepSkyBlue*          = toColor(0x00BFFF'u32) #00BFFF
  DimGray*              = toColor(0x696969'u32) #696969
  DimGrey*              = toColor(0x696969'u32) #696969
  DodgerBlue*           = toColor(0x1E90FF'u32) #1E90FF
  FireBrick*            = toColor(0xB22222'u32) #B22222
  FloralWhite*          = toColor(0xFFFAF0'u32) #FFFAF0
  ForestGreen*          = toColor(0x228B22'u32) #228B22
  Fuchsia*              = toColor(0xFF00FF'u32) #FF00FF
  Gainsboro*            = toColor(0xDCDCDC'u32) #DCDCDC
  GhostWhite*           = toColor(0xF8F8FF'u32) #F8F8FF
  Gold*                 = toColor(0xFFD700'u32) #FFD700
  GoldenRod*            = toColor(0xDAA520'u32) #DAA520
  Gray*                 = toColor(0x808080'u32) #808080
  Green*                = toColor(0x008000'u32) #008000
  GreenYellow*          = toColor(0xADFF2F'u32) #ADFF2F
  Grey*                 = toColor(0x808080'u32) #808080
  HoneyDew*             = toColor(0xF0FFF0'u32) #F0FFF0
  HotPink*              = toColor(0xFF69B4'u32) #FF69B4
  IndianRed*            = toColor(0xCD5C5C'u32) #CD5C5C
  Indigo*               = toColor(0x4B0082'u32) #4B0082
  Ivory*                = toColor(0xFFFFF0'u32) #FFFFF0
  Khaki*                = toColor(0xF0E68C'u32) #F0E68C
  Lavender*             = toColor(0xE6E6FA'u32) #E6E6FA
  LavenderBlush*        = toColor(0xFFF0F5'u32) #FFF0F5
  LawnGreen*            = toColor(0x7CFC00'u32) #7CFC00
  LemonChiffon*         = toColor(0xFFFACD'u32) #FFFACD
  LightBlue*            = toColor(0xADD8E6'u32) #ADD8E6
  LightCoral*           = toColor(0xF08080'u32) #F08080
  LightCyan*            = toColor(0xE0FFFF'u32) #E0FFFF
  LightGoldenRodYellow* = toColor(0xFAFAD2'u32) #FAFAD2
  LightGray*            = toColor(0xD3D3D3'u32) #D3D3D3
  LightGreen*           = toColor(0x90EE90'u32) #90EE90
  LightGrey*            = toColor(0xD3D3D3'u32) #D3D3D3
  LightPink*            = toColor(0xFFB6C1'u32) #FFB6C1
  LightSalmon*          = toColor(0xFFA07A'u32) #FFA07A
  LightSeaGreen*        = toColor(0x20B2AA'u32) #20B2AA
  LightSkyBlue*         = toColor(0x87CEFA'u32) #87CEFA
  LightSlateGray*       = toColor(0x778899'u32) #778899
  LightSlateGrey*       = toColor(0x778899'u32) #778899
  LightSteelBlue*       = toColor(0xB0C4DE'u32) #B0C4DE
  LightYellow*          = toColor(0xFFFFE0'u32) #FFFFE0
  Lime*                 = toColor(0x00FF00'u32) #00FF00
  LimeGreen*            = toColor(0x32CD32'u32) #32CD32
  Linen*                = toColor(0xFAF0E6'u32) #FAF0E6
  Magenta*              = toColor(0xFF00FF'u32) #FF00FF
  Maroon*               = toColor(0x800000'u32) #800000
  MediumAquaMarine*     = toColor(0x66CDAA'u32) #66CDAA
  MediumBlue*           = toColor(0x0000CD'u32) #0000CD
  MediumOrchid*         = toColor(0xBA55D3'u32) #BA55D3
  MediumPurple*         = toColor(0x9370DB'u32) #9370DB
  MediumSeaGreen*       = toColor(0x3CB371'u32) #3CB371
  MediumSlateBlue*      = toColor(0x7B68EE'u32) #7B68EE
  MediumSpringGreen*    = toColor(0x00FA9A'u32) #00FA9A
  MediumTurquoise*      = toColor(0x48D1CC'u32) #48D1CC
  MediumVioletRed*      = toColor(0xC71585'u32) #C71585
  MidnightBlue*         = toColor(0x191970'u32) #191970
  MintCream*            = toColor(0xF5FFFA'u32) #F5FFFA
  MistyRose*            = toColor(0xFFE4E1'u32) #FFE4E1
  Moccasin*             = toColor(0xFFE4B5'u32) #FFE4B5
  NavajoWhite*          = toColor(0xFFDEAD'u32) #FFDEAD
  Navy*                 = toColor(0x000080'u32) #000080
  OldLace*              = toColor(0xFDF5E6'u32) #FDF5E6
  Olive*                = toColor(0x808000'u32) #808000
  OliveDrab*            = toColor(0x6B8E23'u32) #6B8E23
  Orange*               = toColor(0xFFA500'u32) #FFA500
  OrangeRed*            = toColor(0xFF4500'u32) #FF4500
  Orchid*               = toColor(0xDA70D6'u32) #DA70D6
  PaleGoldenRod*        = toColor(0xEEE8AA'u32) #EEE8AA
  PaleGreen*            = toColor(0x98FB98'u32) #98FB98
  PaleTurquoise*        = toColor(0xAFEEEE'u32) #AFEEEE
  PaleVioletRed*        = toColor(0xDB7093'u32) #DB7093
  PapayaWhip*           = toColor(0xFFEFD5'u32) #FFEFD5
  PeachPuff*            = toColor(0xFFDAB9'u32) #FFDAB9
  Peru*                 = toColor(0xCD853F'u32) #CD853F
  Pink*                 = toColor(0xFFC0CB'u32) #FFC0CB
  Plum*                 = toColor(0xDDA0DD'u32) #DDA0DD
  PowderBlue*           = toColor(0xB0E0E6'u32) #B0E0E6
  Purple*               = toColor(0x800080'u32) #800080
  RebeccaPurple*        = toColor(0x663399'u32) #663399
  Red*                  = toColor(0xFF0000'u32) #FF0000
  RosyBrown*            = toColor(0xBC8F8F'u32) #BC8F8F
  RoyalBlue*            = toColor(0x4169E1'u32) #4169E1
  SaddleBrown*          = toColor(0x8B4513'u32) #8B4513
  Salmon*               = toColor(0xFA8072'u32) #FA8072
  SandyBrown*           = toColor(0xF4A460'u32) #F4A460
  SeaGreen*             = toColor(0x2E8B57'u32) #2E8B57
  SeaShell*             = toColor(0xFFF5EE'u32) #FFF5EE
  Sienna*               = toColor(0xA0522D'u32) #A0522D
  Silver*               = toColor(0xC0C0C0'u32) #C0C0C0
  SkyBlue*              = toColor(0x87CEEB'u32) #87CEEB
  SlateBlue*            = toColor(0x6A5ACD'u32) #6A5ACD
  SlateGray*            = toColor(0x708090'u32) #708090
  SlateGrey*            = toColor(0x708090'u32) #708090
  Snow*                 = toColor(0xFFFAFA'u32) #FFFAFA
  SpringGreen*          = toColor(0x00FF7F'u32) #00FF7F
  SteelBlue*            = toColor(0x4682B4'u32) #4682B4
  Tan*                  = toColor(0xD2B48C'u32) #D2B48C
  Teal*                 = toColor(0x008080'u32) #008080
  Thistle*              = toColor(0xD8BFD8'u32) #D8BFD8
  Tomato*               = toColor(0xFF6347'u32) #FF6347
  Turquoise*            = toColor(0x40E0D0'u32) #40E0D0
  Violet*               = toColor(0xEE82EE'u32) #EE82EE
  Wheat*                = toColor(0xF5DEB3'u32) #F5DEB3
  White*                = toColor(0xFFFFFF'u32) #FFFFFF
  WhiteSmoke*           = toColor(0xF5F5F5'u32) #F5F5F5
  Yellow*               = toColor(0xFFFF00'u32) #FFFF00
  YellowGreen*          = toColor(0x9ACD32'u32) #9ACD32

const colorByName* = {
  "AliceBlue": AliceBlue,
  "AntiqueWhite": AntiqueWhite,
  "Aqua": Aqua,
  "Aquamarine": Aquamarine,
  "Azure": Azure,
  "Beige": Beige,
  "Bisque": Bisque,
  "Black": Black,
  "BlanchedAlmond": BlanchedAlmond,
  "Blue": Blue,
  "BlueViolet": BlueViolet,
  "Brown": Brown,
  "BurlyWood": BurlyWood,
  "CadetBlue": CadetBlue,
  "Chartreuse": Chartreuse,
  "Chocolate": Chocolate,
  "Coral": Coral,
  "CornflowerBlue": CornflowerBlue,
  "Cornsilk": Cornsilk,
  "Crimson": Crimson,
  "Cyan": Cyan,
  "DarkBlue": DarkBlue,
  "DarkCyan": DarkCyan,
  "DarkGoldenRod": DarkGoldenRod,
  "DarkGray": DarkGray,
  "DarkGreen": DarkGreen,
  "DarkGrey": DarkGrey,
  "DarkKhaki": DarkKhaki,
  "DarkMagenta": DarkMagenta,
  "DarkOliveGreen": DarkOliveGreen,
  "Darkorange": Darkorange,
  "DarkOrchid": DarkOrchid,
  "DarkRed": DarkRed,
  "DarkSalmon": DarkSalmon,
  "DarkSeaGreen": DarkSeaGreen,
  "DarkSlateBlue": DarkSlateBlue,
  "DarkSlateGray": DarkSlateGray,
  "DarkSlateGrey": DarkSlateGrey,
  "DarkTurquoise": DarkTurquoise,
  "DarkViolet": DarkViolet,
  "DeepPink": DeepPink,
  "DeepSkyBlue": DeepSkyBlue,
  "DimGray": DimGray,
  "DimGrey": DimGrey,
  "DodgerBlue": DodgerBlue,
  "FireBrick": FireBrick,
  "FloralWhite": FloralWhite,
  "ForestGreen": ForestGreen,
  "Fuchsia": Fuchsia,
  "Gainsboro": Gainsboro,
  "GhostWhite": GhostWhite,
  "Gold": Gold,
  "GoldenRod": GoldenRod,
  "Gray": Gray,
  "Green": Green,
  "GreenYellow": GreenYellow,
  "Grey": Grey,
  "HoneyDew": HoneyDew,
  "HotPink": HotPink,
  "IndianRed": IndianRed,
  "Indigo": Indigo,
  "Ivory": Ivory,
  "Khaki": Khaki,
  "Lavender": Lavender,
  "LavenderBlush": LavenderBlush,
  "LawnGreen": LawnGreen,
  "LemonChiffon": LemonChiffon,
  "LightBlue": LightBlue,
  "LightCoral": LightCoral,
  "LightCyan": LightCyan,
  "LightGoldenRodYellow": LightGoldenRodYellow,
  "LightGray": LightGray,
  "LightGreen": LightGreen,
  "LightGrey": LightGrey,
  "LightPink": LightPink,
  "LightSalmon": LightSalmon,
  "LightSeaGreen": LightSeaGreen,
  "LightSkyBlue": LightSkyBlue,
  "LightSlateGray": LightSlateGray,
  "LightSlateGrey": LightSlateGrey,
  "LightSteelBlue": LightSteelBlue,
  "LightYellow": LightYellow,
  "Lime": Lime,
  "LimeGreen": LimeGreen,
  "Linen": Linen,
  "Magenta": Magenta,
  "Maroon": Maroon,
  "MediumAquaMarine": MediumAquaMarine,
  "MediumBlue": MediumBlue,
  "MediumOrchid": MediumOrchid,
  "MediumPurple": MediumPurple,
  "MediumSeaGreen": MediumSeaGreen,
  "MediumSlateBlue": MediumSlateBlue,
  "MediumSpringGreen": MediumSpringGreen,
  "MediumTurquoise": MediumTurquoise,
  "MediumVioletRed": MediumVioletRed,
  "MidnightBlue": MidnightBlue,
  "MintCream": MintCream,
  "MistyRose": MistyRose,
  "Moccasin": Moccasin,
  "NavajoWhite": NavajoWhite,
  "Navy": Navy,
  "OldLace": OldLace,
  "Olive": Olive,
  "OliveDrab": OliveDrab,
  "Orange": Orange,
  "OrangeRed": OrangeRed,
  "Orchid": Orchid,
  "PaleGoldenRod": PaleGoldenRod,
  "PaleGreen": PaleGreen,
  "PaleTurquoise": PaleTurquoise,
  "PaleVioletRed": PaleVioletRed,
  "PapayaWhip": PapayaWhip,
  "PeachPuff": PeachPuff,
  "Peru": Peru,
  "Pink": Pink,
  "Plum": Plum,
  "PowderBlue": PowderBlue,
  "Purple": Purple,
  "RebeccaPurple": RebeccaPurple,
  "Red": Red,
  "RosyBrown": RosyBrown,
  "RoyalBlue": RoyalBlue,
  "SaddleBrown": SaddleBrown,
  "Salmon": Salmon,
  "SandyBrown": SandyBrown,
  "SeaGreen": SeaGreen,
  "SeaShell": SeaShell,
  "Sienna": Sienna,
  "Silver": Silver,
  "SkyBlue": SkyBlue,
  "SlateBlue": SlateBlue,
  "SlateGray": SlateGray,
  "SlateGrey": SlateGrey,
  "Snow": Snow,
  "SpringGreen": SpringGreen,
  "SteelBlue": SteelBlue,
  "Tan": Tan,
  "Teal": Teal,
  "Thistle": Thistle,
  "Tomato": Tomato,
  "Turquoise": Turquoise,
  "Violet": Violet,
  "Wheat": Wheat,
  "White": White,
  "WhiteSmoke": WhiteSmoke,
  "Yellow": Yellow,
  "YellowGreen": YellowGreen
}.toTable