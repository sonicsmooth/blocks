import arraymancer

let foo = vandermonde(arange(1,6), arange(1,6)).asType(int)
echo foo

echo foo[1..2, 3..4]
echo foo[1..<3, 3..<5]
echo foo[_, 3..4]
echo foo[3.._, _]
echo foo[_..2, _]