
proc excl*[T](s: var seq[T], item: T) =
  # Remove all instances of an item from a sequence
  # Uses delete to preserve order (del does not)
  var idx = s.find(item)
  while idx >= 0:
    s.delete(idx)
    idx = s.find(item)

proc parseNumber*[T:SomeNumber](s: string, number: var T): bool =
  # Returns true if s can be parsed to int or float
  # Parsed value is returned in val
  when T is SomeFloat: parseFloat(s, number) > 0
  elif T is SomeInteger: parseInt(s, number) > 0

