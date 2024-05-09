: immediate current @ cell + dup c@ f-immediate or over c! drop ;

: postpone ' , ; immediate

: ['] ' postpone literal ; immediate

: begin here @ ; immediate

: if ['] 0branch , here @ 0 , ; immediate
: then >r here @ r> ! ; immediate

: else ['] branch , here @ >r 0 , postpone then r> ; immediate

: repeat >r [']  branch , , here @ r> ! ; immediate
: until     ['] 0branch , ,             ; immediate
: again     [']  branch , ,             ; immediate

: marker here @ : ['] lit , , ['] here , ['] ! ,
  latest @ ['] lit , , ['] latest , ['] ! , postpone ; ;

: constant : postpone literal postpone ; ;
: variable 0 here @ ! here @ dup cell + here ! constant ;

: ( 41 parse drop drop ; immediate

: lshift ( x1 u -- x2 ) begin dup if >r 2* r> 1- repeat drop ;
: rshift ( x1 u -- x2 ) begin dup if >r 2/ r> 1- repeat drop ;

:  char  ( -- char ) bl word 1+ c@ ;
: [char] ( -- char ) char postpone literal ; immediate

: c" ( -- addr ) ['] branch , here @ >r 0 , here @ [char] " parse s,
  here @ r> ! postpone literal ; immediate
: s" ( -- addr u ) postpone c" ['] count , ; immediate
: ."               postpone s" ['] type  , ; immediate

: hold ( char -- ) 'buffer @ 1- dup 'buffer ! c! ;

: digit ( u -- char ) dup 10 u<
  if [char] 0 + else [ char A 10 - ] literal + then ;

: u. ( u -- ) [ 'buffer 256 + ] literal 'buffer !
  begin base @ /mod >r digit hold r> dup 0= until drop
  'buffer @ [ 'buffer 256 + ] literal over - type ;

:  . ( n -- ) dup 0< if [char] - emit negate then u. ;

: bina  2 base ! ; immediate
: deci 10 base ! ; immediate
: hexa 16 base ! ; immediate
