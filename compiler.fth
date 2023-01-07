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

: digit? ( char -- u bool ) char 0 - 9 over <
  if [ char A char 0 - 10 - ] literal - dup 10 < or then
  dup base @ u< ;

: natural ( addr u1 -- u2 u3 ) push 0 pop
  begin
    push over b@ digit? pop dup push and
  if
    push base @ * pop + push 1+ pop pop 1- 
  repeat
  drop nip pop ;

: number ( addr u1 -- u2 u3 ) over b@ char - = ?jump ' natural ,
  push 1+ pop 1- natural push negate pop ;

: same? ( addr1 addr2 u -- bool )
  begin
    dup push push over b@ over b@ = pop and
  if
    push 1+ pop 1+ pop 1-
  repeat
  pop nip nip 0= ;

: find ( -- 0 | addr ) last
  begin
    @ dup 0= over
    if
      over [ 2 cells ] literal + b@ length and 'buffer b@ =
      if
        drop dup [ 2 cells 1+ ] literal + 'buffer string same?
      then
    then
  until ;

: bmove ( addr1 addr2 u -- )
  begin
    dup
  if
    push over b@ over b! push 1+ pop 1+ pop 1-
  repeat
  nip nip drop ;

: save 'buffer head @ over b@ 1+ dup push aligned - dup head ! collision pop
  bmove ;

: collision top @ head @ u< not
  if [ last @ 2 cells + ] literal string type bye tail then ;

: ,    ( x -- ) top  @ dup cell + top  ! ! collision ; immediate
: link ( x -- ) head @ cell - dup head ! ! collision ; immediate

: tail lit jump top @ [ 2 cells ] literal - dup @ lit call =
  if ! ret then nip drop lit ret postpone , ; immediate
