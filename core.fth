: immediate latest @ cell + dup c@ 128 xor over c! drop ; immediate

: postpone ' , ; immediate

: begin here @ ; immediate

: if lit ?jump , here @ 0 , ; immediate
: then push here @ pop ! ; immediate

: else lit jump , here @ push 0 , postpone then pop ; immediate

: repeat push lit  jump , , here @ pop ! ; immediate
: until       lit ?jump , ,              ; immediate
: again       lit  jump , ,              ; immediate

: variable postpone : lit var , 0 ,    postpone ; ; immediate
: constant postpone : postpone literal postpone ; ; immediate

: ( 41 parse advance ; immediate

: lshift ( x1 u -- x2 ) begin dup if push 2* pop 1- repeat drop ;
: rshift ( x1 u -- x2 ) begin dup if push 2/ pop 1- repeat drop ;

: cells ( n1 -- n2 ) cell * ;

: space 32 emit ;

:  char  ( -- char ) word [ 'buffer 1+ ] literal c@ ;
: [char] ( -- char ) char postpone literal ; immediate

:  " ( -- addr ) [char] " parse advance here @ save ;
: c" ( -- addr ) lit jump , here @ push 0 , " here @ pop ! postpone literal ;
  immediate
: s" ( -- addr u ) postpone c" [ ' count ] literal , ; immediate
: ."               postpone s" [ ' type  ] literal , ; immediate

: hold ( char -- ) 'buffer @ 1- dup 'buffer ! c! ;

: digit ( u -- char ) dup 10 u<
  if [char] 0 + else [ char A 10 - ] literal + then ;

: u. ( u -- ) [ 'buffer 256 + ] literal 'buffer !
  begin 0 base @ um/mod push digit hold pop dup 0= until drop
  'buffer @ [ 'buffer 256 + ] literal over - type ;

: . ( n -- ) dup 0< if [char] - emit negate then u. ;

: bina  2 base ! ; immediate
: deci 10 base ! ; immediate
: hexa 16 base ! ; immediate
