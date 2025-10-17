

type
  MyObject = ref object
    val: int = 5


proc val(myo: MyObject): int =
  echo "getter"
  myo.val

proc `val=`(myo: MyObject, newval: int) =
  echo "setter"
  myo.val = newval

var m = MyObject(val:10)
echo m.val
m.val = 15
echo m.val