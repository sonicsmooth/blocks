
proc p1() = 
  try:
    echo "in try"
    return
  finally:
    echo "in finally"

p1()