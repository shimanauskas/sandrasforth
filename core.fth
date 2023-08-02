: immediate current @ cell + dup c@ f-immediate xor over c! drop ;

: postpone ' , ; immediate

: begin here @ ; immediate

: if [ ' 0branch ] literal , here @ 0 , ; immediate
: then >r here @ r> ! ; immediate

: else [ ' branch ] literal , here @ >r 0 , postpone then r> ; immediate

: repeat >r [ '  branch ] literal , , here @ r> ! ; immediate
: until     [ ' 0branch ] literal , ,             ; immediate
: again     [ '  branch ] literal , ,             ; immediate

: variable : [ ' var ] literal , 0 , postpone ; ; immediate
: constant : postpone  literal       postpone ; ; immediate

: ( 41 parse advance ; immediate

: lshift ( x1 u -- x2 ) begin dup if >r 2* r> 1- repeat drop ;
: rshift ( x1 u -- x2 ) begin dup if >r 2/ r> 1- repeat drop ;

: space 32 emit ;

:  char  ( -- char ) word [ 'buffer 1+ ] literal c@ ;
: [char] ( -- char ) char postpone literal ; immediate

:  " ( -- addr ) [char] " parse advance here @ save ;
: c" ( -- addr ) [ ' branch ] literal , here @ >r 0 ,
   " here @ r> ! postpone literal ; immediate
: s" ( -- addr u ) postpone c" [ ' count ] literal , ; immediate
: ."               postpone s" [ ' type  ] literal , ; immediate

: hold ( char -- ) 'buffer @ 1- dup 'buffer ! c! ;

: digit ( u -- char ) dup 10 u<
  if [char] 0 + else [ char A 10 - ] literal + then ;

: u. ( u -- ) [ 'buffer 256 + ] literal 'buffer !
  begin 0 base @ um/mod >r digit hold r> dup 0= until drop
  'buffer @ [ 'buffer 256 + ] literal over - type ;

: . ( n -- ) dup 0< if [char] - emit negate then u. ;

: bina  2 base ! ; immediate
: deci 10 base ! ; immediate
: hexa 16 base ! ; immediate
