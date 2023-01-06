: [ top @ here ! -1 state ! ; immediate
: ] postpone apply 0 state ! ; immediate

: begin top @ ; immediate

: if lit ?jump postpone , top @ 0 postpone , ; immediate
: then push top @ pop ! ; immediate

: repeat push lit jump postpone , postpone , top @ pop ! ; immediate
: until lit ?jump postpone , postpone , ; immediate

: variable postpone : lit var postpone , 0 postpone , postpone ; ; immediate
: constant postpone : postpone literal lit call postpone ,
  ' literal literal postpone , postpone ; postpone immediate ; immediate

: char word [ 'buffer 1+ ] literal b@ postpone literal ; immediate

: ( begin word? 'buffer b@ 1 =
  [ 'buffer 1+ ] literal b@ char ) = and until ; immediate

: " ( -- addr ) postpone apply begin skip key? until 0 'buffer b!
  begin
    key advance dup char " xor
  if
    accumulate key? not [ over ] until accept
  repeat
  drop save head @ ; immediate

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

: lshift ( x1 u -- x2 ) begin dup if push 2* pop 1- repeat drop ;
: rshift ( x1 u -- x2 ) begin dup if push 2/ pop 1- repeat drop ;

: space 32 emit ;

: * ( n1 n2 -- n3 ) um* drop ;

: cells ( n1 -- n2 ) cell * ;

0 constant stdin
1 constant stdout

: bool ( x -- bool ) if -1 tail then 0 ;

: 0= ( x -- bool ) bool not ;

:  = ( x1 x2 -- bool ) xor 0= ;

: 0< ( n -- bool ) [ 1 8 cells 1- lshift ] literal and bool ;

:  < ( n1 n2 -- bool ) over over xor 0< if drop 0< tail then - 0< ;
: u< ( u1 u2 -- bool ) over over xor 0< if nip  0< tail then - 0< ;

: whithin ( u1 u2 u3 -- bool ) push over push u< not pop pop u< and ;

: aligned ( x1 -- x2 ) [ cell 1- ] literal + [ cell 1- not ] literal and ;

: string ( addr1 -- addr2 u ) dup push 1+ pop b@ ;

: bye flush 0 dup dup sys-exit syscall ( We never return. )

: accept stdin [ 'input 1+ ] literal 255 sys-read syscall dup ?jump ' bye ,
  'input b! [ 'input 1+ ] literal mark ! ;

: flush stdout 'output string sys-write syscall drop 0 'output b! ;

: key? ( -- bool ) mark @ 'input string + u< ;
: key  ( -- char ) mark @ b@ ;

: advance mark @ 1+ mark ! ;

: emit ( char -- ) 'output string + b!
  'output b@ 1+ dup 'output b! 255 xor ?jump ' flush , ;

: type ( addr u -- ) begin dup if push dup b@ emit 1+ pop 1- repeat nip drop ;

: accumulate ( char -- ) 'buffer string dup 1+ 'buffer b! + b! ;

: skip key? not if accept then begin key? key char ! u< and if advance repeat ;

: word? skip 0 'buffer b! key?
  if
    begin
      key dup char ! u< not 'buffer b@ length u< and
    if
      accumulate advance key? not [ over ] until accept
    repeat
    drop
  then ;

: word begin word? 'buffer b@ until ;
