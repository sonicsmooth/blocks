import std/[math, strutils]

proc formatSigFigs*(value: float; sigDigits: Positive; 
                   useScientific = false): string =
  ## Simple significant figures formatting
  ## - useScientific = true  → always 1.23e4 style
  ## - useScientific = false → tries normal notation when reasonable
  
  if sigDigits <= 0:
    raise newException(ValueError, "sigDigits must be positive")
  
  if value == 0.0:
    return "0.0"

  let
    absVal    = abs(value)
    sign      = if value < 0: "-" else: ""
    magnitude = floor(log10(absVal)).int

  # Decide number of decimal places and whether to use scientific
  var decimals: int
  var useSci = useScientific

  if not useSci:
    # Try normal notation if magnitude is reasonable
    if magnitude >= -3 and magnitude <= sigDigits + 4:
      decimals = max(0, sigDigits - 1 - magnitude)
    else:
      useSci = true

  if useSci:
    # Scientific notation path
    let sciExp = magnitude
    let factor = pow(10.0, sciExp.float)
    let mantissaRaw = value / factor
    
    # Round mantissa to required digits
    let scale = pow(10.0, sigDigits.float - 1)
    let roundedMant = round(mantissaRaw * scale) / scale
    
    # Format mantissa with exactly (sigDigits-1) decimal places
    var mantStr = formatFloat(roundedMant, ffDecimal, precision = sigDigits-1)
    
    # Clean up trailing zeros after decimal (optional but nicer)
    if '.' in mantStr:
      mantStr = mantStr.strip(chars = {'0'}, trailing = true)
      if mantStr.endsWith('.'):
        mantStr = mantStr[0 .. ^2]  # remove trailing dot
    
    let expSign = if sciExp >= 0: "+" else: ""
    return sign & mantStr & "e" & expSign & $abs(sciExp)

  else:
    # Normal decimal notation
    let scale = pow(10.0, decimals.float)
    let rounded = round(value * scale) / scale
    return sign & formatFloat(rounded, ffDecimal, precision = decimals)


# Quick test / usage helpers
proc `$~`*(x: float; digits: Positive): string {.inline.} =
  formatSigFigs(x, digits, useScientific = false)

proc `$~~`*(x: float; digits: Positive): string {.inline.} =
  formatSigFigs(x, digits, useScientific = true)


when isMainModule:
  echo 12345678 $~ 4          # → "123.5"
  echo 12345678 $~~ 4          # → "123.5"
  echo 0.00123456 $~ 4         # → "0.001235"
  echo 987654321.0 $~ 3        # → "9.88e+8"
  echo 1.2345678e-6 $~ 4      # → "1.235e-6"
  echo 999.5 $~ 3              # → "1000"
  echo 1234567890123.0 $~ 4    # → "1.235e+12"