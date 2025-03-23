import std/typetraits
import std/strutils

# https://www.nist.gov/pml/owm/metric-si/si-units
# https://www.animalia-life.club/qa/pictures/si-derived-units
# https://uncleofmagic.blogspot.com/2011/03/electrical-fundamentals.html


type
  Quantity[L,M,T] = distinct float
  Meters          = distinct Quantity[1,0,0]
  Kilograms       = distinct Quantity[0,1,0]
  Seconds         = distinct Quantity[0,0,1]
  Speed           = distinct Quantity[1,0,-1]
  SomeQuantity    = Meters | Kilograms | Seconds | Speed


proc junk1[L,M,T](val: Quantity[L,M,T]): string =
  # Trying to get integer values of L,M,T
  # Doesn't compile if junk1 is called below.
  # Type mismatch expected val to be Quantity not Meters
  discard

#proc junk2[T:Quantity[L,M,T]](val: T): string =
  # Trying to get integer values of L,M,T
  # Doesn't compile at all, even without calling junk2 below.
  # Undeclared identifier L
#  discard

proc junk3[T:SomeQuantity](val: T): string = 
  # Compiles, T is Meters or Kilograms
  # How do I get the values of L,M,T ?
  $T

proc junk4[T:SomeQuantity](val: T) =
  echo T.arity               # -> 1
  echo Meters.arity          # -> 1
  echo Quantity.arity        # -> 4
  echo SomeQuantity.arity    # -> 4
  echo Quantity[1,0,0].arity # -> 5

  echo T.distinctBase               # -> float
  echo Meters.distinctBase          # -> float
  echo Quantity.distinctBase        # -> Quantity
  echo SomeQuantity.distinctBase    # -> SomeQuantity
  echo Quantity[1,0,0].distinctBase # -> float

  echo T.distinctBase(false)               # -> Quantity
  echo Meters.distinctBase(false)          # -> Quantity
  echo Quantity.distinctBase(false)        # -> Quantity
  echo SomeQuantity.distinctBase(false)    # -> SomeQuantity
  echo Quantity[1,0,0].distinctBase(false) # -> float

  echo Quantity[1,0,0].genericParams                      # -> (StaticParam[1], StaticParam[0], StaticParam[0])
  echo Quantity[1,0,0].genericParams.get(0)               # -> StaticParam[1]
  echo Quantity[1,0,0].genericParams.get(1)               # -> StaticParam[0]
  echo Quantity[1,0,0].genericParams.get(2)               # -> StaticParam[0]
  echo Quantity[1,0,0].genericParams.get(0).value         # -> 1
  echo Quantity[1,0,0].genericParams.get(1).value         # -> 0
  echo Quantity[1,0,0].genericParams.get(2).value         # -> 0
  echo Quantity[1,0,0].genericParams.get(0).value.typeof  # -> int (yay!)
  echo Quantity[1,0,0].genericParams.get(1).value.typeof  # -> int (yay!)
  echo Quantity[1,0,0].genericParams.get(2).value.typeof  # -> int (yay!)

let len1 = Meters(10.0)
let mass1 = Kilograms(5.0)
echo junk3(len1) # -> Meters
echo junk3(mass1) # -> Kilograms
junk4(len1) # -> explorations with typetraits