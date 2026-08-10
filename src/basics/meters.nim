import std/[math, strformat]

type
  LengthT    = int64
  Picometer  = object
    mVal: LengthT # always nanometers
  Nanometer  = object
    mVal: LengthT # always nanometers
  Micrometer = object
    mVal: LengthT # always nanometers
  Millimeter = object
    mVal: LengthT # always nanometers
  Meter      = object
    mVal: LengthT # always nanometers
  Centimeter = object
    mVal: LengthT # always nanometers
  Kilometer  = object
    mVal: LengthT # always nanometers

  SomeLength = Picometer | Nanometer | Micrometer | 
               Millimeter | Centimeter | Meter | Kilometer

const
  NANO  = 1
  MICRO = 1_000
  MILLI = 1_000_000
  CENTI = 1_000_000_0
  UNI   = 1_000_000_000
  KILO  = 1_000_000_000_000

proc `$`[T:SomeLength](val: T): string =
  let vf = val.mVal.float
  let u = 
    when T is Nanometer:  vf / NANO.float
    elif T is Micrometer: vf / MICRO.float
    elif T is Millimeter: vf / MILLI.float
    elif T is Centimeter: vf / CENTI.float
    elif T is Meter:      vf / UNI.float
    elif T is Kilometer:  vf / KILO.float
  let suf =
    when T is Nanometer:  "nm"
    elif T is Micrometer: "um"
    elif T is Millimeter: "mm"
    elif T is Centimeter: "cm"
    elif T is Meter:      "m"
    elif T is Kilometer:  "km"
  result = &"{u:0.8g} {suf}"


proc `+`[A, B: SomeLength](a: A, b: B): A =
  result.mVal = a.mVal.LengthT + b.mVal.LengthT

proc `*`[A: SomeLength, B: SomeNumber](a: A, b: B): A =
  when B is SomeInteger:
    result.mVal = a.mVal.LengthT * b.LengthT
  elif B is SomeFloat:
    result.mVal = (a.mVal.float * b).round.LengthT


proc `*`[A: SomeNumber, B: SomeLength](a: A, b: B): A =
  when A is SomeInteger:
    result.mVal = a.mVal.LengthT * b.LengthT
  elif A is SomeFloat:
    result.mVal = (a.mVal.float * b).round.LengthT


#proc pm(val: SomeLength): Picometer  = result.mVal = val.mVal
proc nm(val: SomeLength): Nanometer  = result.mVal = val.mVal
proc um(val: SomeLength): Micrometer = result.mVal = val.mVal
proc mm(val: SomeLength): Millimeter = result.mVal = val.mVal
proc cm(val: SomeLength): Centimeter = result.mVal = val.mVal
proc  m(val: SomeLength): Meter      = result.mVal = val.mVal
proc km(val: SomeLength): Kilometer  = result.mVal = val.mVal

#proc pm(val: SomeInteger): Picometer  = result.mVal = (val * PICO ).LengthT
proc nm(val: SomeInteger): Nanometer  = result.mVal = (val * NANO ).LengthT
proc um(val: SomeInteger): Micrometer = result.mVal = (val * MICRO).LengthT
proc mm(val: SomeInteger): Millimeter = result.mVal = (val * MILLI).LengthT
proc cm(val: SomeInteger): Centimeter = result.mVal = (val * CENTI).LengthT
proc  m(val: SomeInteger): Meter      = result.mVal = (val * UNI  ).LengthT
proc km(val: SomeInteger): Kilometer  = result.mVal = (val * KILO ).LengthT

#proc pm(val: SomeFloat): Picometer  = result.mVal = (val * PICO.float ).round.LengthT
proc nm(val: SomeFloat): Nanometer  = result.mVal = (val * NANO.float ).round.LengthT
proc um(val: SomeFloat): Micrometer = result.mVal = (val * MICRO.float).round.LengthT
proc mm(val: SomeFloat): Millimeter = result.mVal = (val * MILLI.float).round.LengthT
proc cm(val: SomeFloat): Centimeter = result.mVal = (val * CENTI.float).round.LengthT
proc  m(val: SomeFloat): Meter      = result.mVal = (val * UNI.float  ).round.LengthT
proc km(val: SomeFloat): Kilometer  = result.mVal = (val * KILO.float ).round.LengthT



when isMainModule:
  #let a = 1.234567.km
  let b = 52.km.m
  echo b.mVal
  echo b * 2.5123
  echo (b * 2.5123).mVal


  # for m in [PICO, NANO, MICRO, MILLI, CENTI, UNI, KILO]:
  #   let ma = a * m
  #   echo $ma.LengthT
  #   echo $ma
  #   echo $ma.nm
  #   echo $ma.um
  #   echo $ma.mm
  #   echo $ma.cm
  #   echo $ma.m
  #   echo $ma.km
  #   echo ""

