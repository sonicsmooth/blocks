import std/strformat

let val1 = 100.0
echo &"{val1:f}"   # -> "100.000000"
echo &"{val1:.f}"  # -> "100."
echo &"{val1:.0f}" # -> "100."
echo &"{val1:.1f}" # -> "100.0"
echo &"{val1:.2f}" # -> "100.00"
echo &"{val1:g}"   # -> "100" <-- looks good
echo &"{val1:.g}"  # -> "1.e+02"
echo &"{val1:.0g}" # -> "1.e+02"
echo &"{val1:.1g}" # -> "1.e+02"
echo &"{val1:.2g}" # -> "1.0e+02"

let val2 = 100.05
echo &"{val2:f}"   # -> "100.000000"
echo &"{val2:.f}"  # -> "100."
echo &"{val2:.0f}" # -> "100."
echo &"{val2:.1f}" # -> "100.0"
echo &"{val2:.2f}" # -> "100.00"
echo &"{val2:g}"   # -> "100" <-- net

let val3 = 100.001
echo &"{val3:f}"   # -> "100.000000"
echo &"{val3:.f}"  # -> "100."
echo &"{val3:.0f}" # -> "100."
echo &"{val3:.1f}" # -> "100.0"
echo &"{val3:.2f}" # -> "100.00"
echo &"{val3:g}"   # -> "100" <-- net










