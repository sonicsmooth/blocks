
# These are types shared by compact algorithm and compact dialog box
type
  CompactDir* = enum 
    Left, Right, Up, Down,
    UpLeft, UpRight, DownLeft, DownRight,
    LeftUp, LeftDown, RightUp, RightDown
  CornerDir* = range[UpLeft..RightDown]
  CompactMethod* = enum None, Stack, Anneal
  StrategyOption* = enum Strat1, Strat2
  ReplacementOption* = enum Wiggle, Swap



