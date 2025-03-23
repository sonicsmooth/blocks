
import std/sets


proc f1(s: array[3,int]) =
  echo ""
  echo typeof(s)
  echo s

proc f2(s: seq[int]) =
  echo ""
  echo typeof(s)
  echo s

proc f3(s: openArray[int]) =
  echo ""
  when typeof(s) is seq[int]:
    echo "it's a seq"
  elif typeof(s) is array[3,int]:
    echo "it's an array"
  echo s

proc f4(s: HashSet[int]) =
  echo ""
  echo typeof(s)
  echo s

#proc f5(s: openArray[int] | array[3,int])  = #ok with array only
#proc f5(s: openArray[int] | seq[int])      = #ok with seq only
#proc f5(s: openArray[int])                 = #ok with seq and array
#proc f5(s: openArray[int] | HashSet[int])  = #ok with HashSet only
#proc f5(s: array[3,int] | HashSet[int])    = #ok with array and HashSet only
proc f5(s: seq[int] | HashSet[int])         = #ok with seq and HashSet only
  echo ""
  echo typeof(s)
  echo s


let s1: array[3,int] = [1,2,3]
let s2: seq[int] = @[4,5,6]
let s3: HashSet[int] = [7,8,9].toHashSet

# f1(s1)
# f2(s2)
# f3(s1)
# f3(s2)
# f4(s3)
f5(s3)