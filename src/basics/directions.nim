
type
  CompactDir* = enum 
    Left, Right, Up, Down,
    UpLeft, UpRight, DownLeft, DownRight,
    LeftUp, LeftDown, RightUp, RightDown
  CompactMethod* = enum None, Stack, Anneal
  StrategyOption* = enum Strat1, Strat2
  ReplacementOption* = enum Wiggle, Swap



