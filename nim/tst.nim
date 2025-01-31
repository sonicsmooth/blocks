import std/strformat
import std/tables

iterator counter(a, b, amt: int): int {.closure.} =
  var x = a
  while x < b:
    yield x
    x += amt

echo counter(5,20,3)
echo counter(5,20,3)
echo counter(5,20,3)

#for i in counter(5,20,3):
#  echo i