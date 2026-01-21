: immediate current @ cell + dup c@ immediate-flag or over c! drop ;

: ( 41 parse nip drop ; immediate

: postpone ' , ; immediate

: ['] ( -- xt ) ' postpone literal ; immediate

: begin ( -- addr ) here @ ; immediate

: if   ( -- addr ) ['] 0branch , here @ 0 , ; immediate
: then ( addr -- ) >r here @ r> ! ; immediate

: else ( addr1 -- addr2 )
  ['] branch , here @ >r 0 , postpone then r> ; immediate

: repeat ( addr1 addr2 -- ) >r [']  branch , , here @ r> ! ; immediate
: until  ( addr -- )           ['] 0branch , ,             ; immediate
: again  ( addr -- )           [']  branch , ,             ; immediate

: recurse current @ >code , ; immediate

: marker here @ : ['] lit , , ['] here , ['] ! ,
  latest @ ['] lit , , ['] latest , ['] ! , postpone ; ;

: constant ( x -- ) : postpone literal postpone ; ;
: variable here @ 0 over ! dup cell + here ! constant ;

:  char  ( -- char ) bl word 1+ c@ ;
: [char] ( -- char ) char postpone literal ; immediate

: c" ( -- addr ) ['] branch , here @ >r 0 , here @ [char] " parse s,
  here @ r> ! postpone literal ; immediate
: s" ( -- addr u ) postpone c" ['] count , ; immediate
: ."               postpone s" ['] type  , ; immediate

: digit ( u -- char ) dup 10 u<
  if [char] 0 + else [ char A 10 - ] literal + then ;

: u. ( u -- ) 0 base @ um/mod dup if recurse else drop then digit emit ;

:  . ( n -- ) dup 0< if [char] - emit negate then u. ;

: bina  2 base ! ; immediate
: deci 10 base ! ; immediate
: hexa 16 base ! ; immediate
