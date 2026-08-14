
from std/random import rand
from std/math import round, clamp
import std/tables

type
  ColorRGBA* = object # Same as Pixie's ColorRGBA
    r*: uint8
    g*: uint8
    b*: uint8
    a*: uint8
  ColorFloat* = object # Same as Pixie's Color
    r*: float32
    g*: float32
    b*: float32
    a*: float32

proc colorRGBA*(r,g,b: uint8): ColorRGBA =
  ColorRGBA(r: r, g: g, b: b, a: 255)

proc colorRGBA*(r,g,b,a,: uint8): ColorRGBA =
  ColorRGBA(r: r, g: g, b: b, a: a)

proc setAlpha*(c: ColorRGBA, a: uint8): ColorRGBA =
  ColorRGBA(r: c.r, g: c.g, b: c.b, a: a)

proc toColorRGBA*(val: uint32): ColorRGBA =
  # Assume val is only RGB.
  result.r = ((val shr 16) and 0xff).uint8
  result.g = ((val shr  8) and 0xff).uint8
  result.b = ((val shr  0) and 0xff).uint8
  result.a = 255.uint8

proc toColorRGBA*(val: uint32, alpha: uint8): ColorRGBA =
  # Assume val is only RGB.
  result.r = ((val shr 16) and 0xff).uint8
  result.g = ((val shr  8) and 0xff).uint8
  result.b = ((val shr  0) and 0xff).uint8
  result.a = alpha

proc toColorRGBA*(val: ColorFloat): ColorRGBA =
  result.r = clamp(round(255 * val.r),0, 255).uint8
  result.g = clamp(round(255 * val.g),0, 255).uint8
  result.b = clamp(round(255 * val.b),0, 255).uint8
  result.a = clamp(round(255 * val.a),0, 255).uint8

proc toColorFloat*(val: ColorRGBA): ColorFloat =
  result.r = val.r.float / 255.0
  result.g = val.g.float / 255.0
  result.b = val.b.float / 255.0
  result.a = val.a.float / 255.0


proc randColor*(): ColorRGBA =
  result.r = rand(255).uint8
  result.g = rand(255).uint8
  result.b = rand(255).uint8
  result.a = 200'u8

proc toU32_RGB*(val: ColorRGBA): uint32 =
  let
    r: uint32 = val.r.uint32 shl 16
    g: uint32 = val.g.uint32 shl  8
    b: uint32 = val.b.uint32 shl  0
  r or g or b

proc toU32_RGBA*(val: ColorRGBA): uint32 =
  let
    r: uint32 = val.r.uint32 shl 24
    g: uint32 = val.g.uint32 shl 16
    b: uint32 = val.b.uint32 shl  8
    a: uint32 = val.a.uint32 shl  0
  r or g or b or a

proc `*`*(val: ColorRGBA, scale: float): ColorRGBA =
  result.r = (val.r.float * scale).clamp(0, 255).round.uint8
  result.g = (val.g.float * scale).clamp(0, 255).round.uint8
  result.b = (val.b.float * scale).clamp(0, 255).round.uint8
  result.a = val.a

proc `-`*(val: ColorRGBA, amt: uint8): ColorRGBA =
  result.r = if val.r - amt <= val.r: val.r - amt else: 0
  result.g = if val.g - amt <= val.g: val.g - amt else: 0
  result.b = if val.b - amt <= val.b: val.b - amt else: 0
  result.a = val.a

proc `+`*(val: ColorRGBA, amt: uint8): ColorRGBA =
  result.r = if val.r + amt >= val.r: val.r + amt else: 255
  result.g = if val.g + amt >= val.g: val.g + amt else: 255
  result.b = if val.b + amt >= val.b: val.b + amt else: 255
  result.a = val.a

proc `$`*(val: ColorRGBA): string =
  result = "(r: " & $val.r.int & ", " &
           " g: " & $val.g.int & ", " &
           " b: " & $val.b.int & ", " &
           " a: " & $val.a.int & ")"

const
  AliceBlue*            = toColorRGBA(0xF0F8FF'u32) #F0F8FF
  AntiqueWhite*         = toColorRGBA(0xFAEBD7'u32) #FAEBD7
  Aqua*                 = toColorRGBA(0x00FFFF'u32) #00FFFF
  Aquamarine*           = toColorRGBA(0x7FFFD4'u32) #7FFFD4
  Azure*                = toColorRGBA(0xF0FFFF'u32) #F0FFFF
  Beige*                = toColorRGBA(0xF5F5DC'u32) #F5F5DC
  Bisque*               = toColorRGBA(0xFFE4C4'u32) #FFE4C4
  Black*                = toColorRGBA(0x000000'u32) #000000
  BlanchedAlmond*       = toColorRGBA(0xFFEBCD'u32) #FFEBCD
  Blue*                 = toColorRGBA(0x0000FF'u32) #0000FF
  BlueViolet*           = toColorRGBA(0x8A2BE2'u32) #8A2BE2
  Brown*                = toColorRGBA(0xA52A2A'u32) #A52A2A
  BurlyWood*            = toColorRGBA(0xDEB887'u32) #DEB887
  CadetBlue*            = toColorRGBA(0x5F9EA0'u32) #5F9EA0
  Chartreuse*           = toColorRGBA(0x7FFF00'u32) #7FFF00
  Chocolate*            = toColorRGBA(0xD2691E'u32) #D2691E
  Coral*                = toColorRGBA(0xFF7F50'u32) #FF7F50
  CornflowerBlue*       = toColorRGBA(0x6495ED'u32) #6495ED
  Cornsilk*             = toColorRGBA(0xFFF8DC'u32) #FFF8DC
  Crimson*              = toColorRGBA(0xDC143C'u32) #DC143C
  Cyan*                 = toColorRGBA(0x00FFFF'u32) #00FFFF
  DarkBlue*             = toColorRGBA(0x00008B'u32) #00008B
  DarkCyan*             = toColorRGBA(0x008B8B'u32) #008B8B
  DarkGoldenRod*        = toColorRGBA(0xB8860B'u32) #B8860B
  DarkGray*             = toColorRGBA(0xA9A9A9'u32) #A9A9A9
  DarkGreen*            = toColorRGBA(0x006400'u32) #006400
  DarkGrey*             = toColorRGBA(0xA9A9A9'u32) #A9A9A9
  DarkKhaki*            = toColorRGBA(0xBDB76B'u32) #BDB76B
  DarkMagenta*          = toColorRGBA(0x8B008B'u32) #8B008B
  DarkOliveGreen*       = toColorRGBA(0x556B2F'u32) #556B2F
  Darkorange*           = toColorRGBA(0xFF8C00'u32) #FF8C00
  DarkOrchid*           = toColorRGBA(0x9932CC'u32) #9932CC
  DarkRed*              = toColorRGBA(0x8B0000'u32) #8B0000
  DarkSalmon*           = toColorRGBA(0xE9967A'u32) #E9967A
  DarkSeaGreen*         = toColorRGBA(0x8FBC8F'u32) #8FBC8F
  DarkSlateBlue*        = toColorRGBA(0x483D8B'u32) #483D8B
  DarkSlateGray*        = toColorRGBA(0x2F4F4F'u32) #2F4F4F
  DarkSlateGrey*        = toColorRGBA(0x2F4F4F'u32) #2F4F4F
  DarkTurquoise*        = toColorRGBA(0x00CED1'u32) #00CED1
  DarkViolet*           = toColorRGBA(0x9400D3'u32) #9400D3
  DeepPink*             = toColorRGBA(0xFF1493'u32) #FF1493
  DeepSkyBlue*          = toColorRGBA(0x00BFFF'u32) #00BFFF
  DimGray*              = toColorRGBA(0x696969'u32) #696969
  DimGrey*              = toColorRGBA(0x696969'u32) #696969
  DodgerBlue*           = toColorRGBA(0x1E90FF'u32) #1E90FF
  FireBrick*            = toColorRGBA(0xB22222'u32) #B22222
  FloralWhite*          = toColorRGBA(0xFFFAF0'u32) #FFFAF0
  ForestGreen*          = toColorRGBA(0x228B22'u32) #228B22
  Fuchsia*              = toColorRGBA(0xFF00FF'u32) #FF00FF
  Gainsboro*            = toColorRGBA(0xDCDCDC'u32) #DCDCDC
  GhostWhite*           = toColorRGBA(0xF8F8FF'u32) #F8F8FF
  Gold*                 = toColorRGBA(0xFFD700'u32) #FFD700
  GoldenRod*            = toColorRGBA(0xDAA520'u32) #DAA520
  Gray*                 = toColorRGBA(0x808080'u32) #808080
  Green*                = toColorRGBA(0x008000'u32) #008000
  GreenYellow*          = toColorRGBA(0xADFF2F'u32) #ADFF2F
  Grey*                 = toColorRGBA(0x808080'u32) #808080
  HoneyDew*             = toColorRGBA(0xF0FFF0'u32) #F0FFF0
  HotPink*              = toColorRGBA(0xFF69B4'u32) #FF69B4
  IndianRed*            = toColorRGBA(0xCD5C5C'u32) #CD5C5C
  Indigo*               = toColorRGBA(0x4B0082'u32) #4B0082
  Ivory*                = toColorRGBA(0xFFFFF0'u32) #FFFFF0
  Khaki*                = toColorRGBA(0xF0E68C'u32) #F0E68C
  Lavender*             = toColorRGBA(0xE6E6FA'u32) #E6E6FA
  LavenderBlush*        = toColorRGBA(0xFFF0F5'u32) #FFF0F5
  LawnGreen*            = toColorRGBA(0x7CFC00'u32) #7CFC00
  LemonChiffon*         = toColorRGBA(0xFFFACD'u32) #FFFACD
  LightBlue*            = toColorRGBA(0xADD8E6'u32) #ADD8E6
  LightCoral*           = toColorRGBA(0xF08080'u32) #F08080
  LightCyan*            = toColorRGBA(0xE0FFFF'u32) #E0FFFF
  LightGoldenRodYellow* = toColorRGBA(0xFAFAD2'u32) #FAFAD2
  LightGray*            = toColorRGBA(0xD3D3D3'u32) #D3D3D3
  LightGreen*           = toColorRGBA(0x90EE90'u32) #90EE90
  LightGrey*            = toColorRGBA(0xD3D3D3'u32) #D3D3D3
  LightPink*            = toColorRGBA(0xFFB6C1'u32) #FFB6C1
  LightSalmon*          = toColorRGBA(0xFFA07A'u32) #FFA07A
  LightSeaGreen*        = toColorRGBA(0x20B2AA'u32) #20B2AA
  LightSkyBlue*         = toColorRGBA(0x87CEFA'u32) #87CEFA
  LightSlateGray*       = toColorRGBA(0x778899'u32) #778899
  LightSlateGrey*       = toColorRGBA(0x778899'u32) #778899
  LightSteelBlue*       = toColorRGBA(0xB0C4DE'u32) #B0C4DE
  LightYellow*          = toColorRGBA(0xFFFFE0'u32) #FFFFE0
  Lime*                 = toColorRGBA(0x00FF00'u32) #00FF00
  LimeGreen*            = toColorRGBA(0x32CD32'u32) #32CD32
  Linen*                = toColorRGBA(0xFAF0E6'u32) #FAF0E6
  Magenta*              = toColorRGBA(0xFF00FF'u32) #FF00FF
  Maroon*               = toColorRGBA(0x800000'u32) #800000
  MediumAquaMarine*     = toColorRGBA(0x66CDAA'u32) #66CDAA
  MediumBlue*           = toColorRGBA(0x0000CD'u32) #0000CD
  MediumOrchid*         = toColorRGBA(0xBA55D3'u32) #BA55D3
  MediumPurple*         = toColorRGBA(0x9370DB'u32) #9370DB
  MediumSeaGreen*       = toColorRGBA(0x3CB371'u32) #3CB371
  MediumSlateBlue*      = toColorRGBA(0x7B68EE'u32) #7B68EE
  MediumSpringGreen*    = toColorRGBA(0x00FA9A'u32) #00FA9A
  MediumTurquoise*      = toColorRGBA(0x48D1CC'u32) #48D1CC
  MediumVioletRed*      = toColorRGBA(0xC71585'u32) #C71585
  MidnightBlue*         = toColorRGBA(0x191970'u32) #191970
  MintCream*            = toColorRGBA(0xF5FFFA'u32) #F5FFFA
  MistyRose*            = toColorRGBA(0xFFE4E1'u32) #FFE4E1
  Moccasin*             = toColorRGBA(0xFFE4B5'u32) #FFE4B5
  NavajoWhite*          = toColorRGBA(0xFFDEAD'u32) #FFDEAD
  Navy*                 = toColorRGBA(0x000080'u32) #000080
  OldLace*              = toColorRGBA(0xFDF5E6'u32) #FDF5E6
  Olive*                = toColorRGBA(0x808000'u32) #808000
  OliveDrab*            = toColorRGBA(0x6B8E23'u32) #6B8E23
  Orange*               = toColorRGBA(0xFFA500'u32) #FFA500
  OrangeRed*            = toColorRGBA(0xFF4500'u32) #FF4500
  Orchid*               = toColorRGBA(0xDA70D6'u32) #DA70D6
  PaleGoldenRod*        = toColorRGBA(0xEEE8AA'u32) #EEE8AA
  PaleGreen*            = toColorRGBA(0x98FB98'u32) #98FB98
  PaleTurquoise*        = toColorRGBA(0xAFEEEE'u32) #AFEEEE
  PaleVioletRed*        = toColorRGBA(0xDB7093'u32) #DB7093
  PapayaWhip*           = toColorRGBA(0xFFEFD5'u32) #FFEFD5
  PeachPuff*            = toColorRGBA(0xFFDAB9'u32) #FFDAB9
  Peru*                 = toColorRGBA(0xCD853F'u32) #CD853F
  Pink*                 = toColorRGBA(0xFFC0CB'u32) #FFC0CB
  Plum*                 = toColorRGBA(0xDDA0DD'u32) #DDA0DD
  PowderBlue*           = toColorRGBA(0xB0E0E6'u32) #B0E0E6
  Purple*               = toColorRGBA(0x800080'u32) #800080
  RebeccaPurple*        = toColorRGBA(0x663399'u32) #663399
  Red*                  = toColorRGBA(0xFF0000'u32) #FF0000
  RosyBrown*            = toColorRGBA(0xBC8F8F'u32) #BC8F8F
  RoyalBlue*            = toColorRGBA(0x4169E1'u32) #4169E1
  SaddleBrown*          = toColorRGBA(0x8B4513'u32) #8B4513
  Salmon*               = toColorRGBA(0xFA8072'u32) #FA8072
  SandyBrown*           = toColorRGBA(0xF4A460'u32) #F4A460
  SeaGreen*             = toColorRGBA(0x2E8B57'u32) #2E8B57
  SeaShell*             = toColorRGBA(0xFFF5EE'u32) #FFF5EE
  Sienna*               = toColorRGBA(0xA0522D'u32) #A0522D
  Silver*               = toColorRGBA(0xC0C0C0'u32) #C0C0C0
  SkyBlue*              = toColorRGBA(0x87CEEB'u32) #87CEEB
  SlateBlue*            = toColorRGBA(0x6A5ACD'u32) #6A5ACD
  SlateGray*            = toColorRGBA(0x708090'u32) #708090
  SlateGrey*            = toColorRGBA(0x708090'u32) #708090
  Snow*                 = toColorRGBA(0xFFFAFA'u32) #FFFAFA
  SpringGreen*          = toColorRGBA(0x00FF7F'u32) #00FF7F
  SteelBlue*            = toColorRGBA(0x4682B4'u32) #4682B4
  Tan*                  = toColorRGBA(0xD2B48C'u32) #D2B48C
  Teal*                 = toColorRGBA(0x008080'u32) #008080
  Thistle*              = toColorRGBA(0xD8BFD8'u32) #D8BFD8
  Tomato*               = toColorRGBA(0xFF6347'u32) #FF6347
  Turquoise*            = toColorRGBA(0x40E0D0'u32) #40E0D0
  Violet*               = toColorRGBA(0xEE82EE'u32) #EE82EE
  Wheat*                = toColorRGBA(0xF5DEB3'u32) #F5DEB3
  White*                = toColorRGBA(0xFFFFFF'u32) #FFFFFF
  WhiteSmoke*           = toColorRGBA(0xF5F5F5'u32) #F5F5F5
  Yellow*               = toColorRGBA(0xFFFF00'u32) #FFFF00
  YellowGreen*          = toColorRGBA(0x9ACD32'u32) #9ACD32

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