: immediate last @ nfa + dup b@ 128 xor over b! drop ; immediate
: hidden    last @ nfa + dup b@  64 xor over b! drop ; immediate

: [ commit 0 state ! ; immediate
: ] apply -1 state ! ; immediate

: begin top @ ; immediate

: if lit ?jump postpone , top @ 0 postpone , ; immediate
: then push top @ pop ! ; immediate

: repeat push lit jump postpone , postpone , top @ pop ! ; immediate
: until lit ?jump postpone , postpone , ; immediate

: variable postpone : lit var postpone , 0 postpone , postpone ; ; immediate
: constant postpone : postpone literal lit call postpone ,
  ' literal literal postpone , postpone ; postpone immediate ; immediate

: ( begin word 'buffer b@ 1 = [ 'buffer 1+ ] literal b@ 41 = and until ;
  immediate

: lshift ( x1 u -- x2 ) begin dup if push 2* pop 1- repeat drop ;
: rshift ( x1 u -- x2 ) begin dup if push 2/ pop 1- repeat drop ;

: cells ( n1 -- n2 ) cell * ;

: space 32 emit ;

: char ( -- char ) word [ 'buffer 1+ ] literal b@ postpone literal ; immediate

: " ( -- addr ) skip 0 'buffer b!
  begin
    key dup char " xor 'buffer b@ 255 u< and
  if
    accumulate advance key? not [ over ] until accept
  repeat
  char " = if advance then
  save head @ ; immediate

: hold ( char -- ) 'buffer @ 1- dup 'buffer ! b! ;

: digit ( u -- char ) dup 10 u<
  if char 0 + tail then [ char A 10 - ] literal + ;

: u. ( u -- ) [ 'buffer 256 + ] literal 'buffer !
  begin 0 base @ um/mod push digit hold pop dup 0= until drop
  'buffer @ [ 'buffer 256 + ] literal over - type ;

: . ( n -- ) dup 0< if char - emit negate then u. ;

: bina  2 base ! ; immediate
: deci 10 base ! ; immediate
: hexa 16 base ! ; immediate
