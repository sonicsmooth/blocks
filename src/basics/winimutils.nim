from winim import LOWORD, HIWORD, WORD, LPARAM, WPARAM

template paramSplit*(x: LPARAM|WPARAM): auto =
  (LOWORD(x).WORD,
   HIWORD(x).WORD)

