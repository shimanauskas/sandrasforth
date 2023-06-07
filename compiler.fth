: bool ( x -- bool ) if -1 ret then 0 ;

: 0= ( x -- bool ) bool invert ;

:  = ( x1 x2 -- bool ) xor 0= ;

: 0< ( n -- bool ) [ 1 8 cells 1- lshift ] literal and bool ;

:  < ( n1 n2 -- bool ) over over xor 0< if drop 0< ret then - 0< ;
: u< ( u1 u2 -- bool ) over over xor 0< if nip  0< ret then - 0< ;

: whithin ( u1 u2 u3 -- bool ) push over push u< invert pop pop u< and ;

: aligned ( x1 -- x2 ) [ cell 1- ] literal + [ cell 1- invert ] literal and ;

: count ( addr1 -- addr2 u ) dup push 1+ pop b@ ;

: bmove ( addr1 addr2 u -- )
  begin dup if push over b@ over b! push 1+ pop 1+ pop 1- repeat
  nip nip drop ;

: same? ( addr1 addr2 u -- bool )
  begin dup push push over b@ over b@ = pop and if push 1+ pop 1+ pop 1- repeat
  pop nip nip 0= ;

: write 1 'output count sys-write syscall drop 0 'output b! ;

: bye write 0 dup dup sys-exit syscall ( We never return. )

: read 0 [ 'input 1+ ] literal 255 sys-read syscall dup
  if 'input b! [ 'input 1+ ] literal mark ! ret then bye

: key? ( -- bool ) mark @ 'input count + u< ;
: key  ( -- char ) mark @ b@ dup 10 = if drop 32 then ;

: advance mark @ 1+ mark ! ;

: emit ( char -- ) 'output count + b!
  'output b@ 1+ dup 'output b! 255 xor if ret then write ;

: type ( addr u -- ) begin dup if push dup b@ emit 1+ pop 1- repeat nip drop ;

: accumulate ( char -- ) 'buffer count dup 1+ 'buffer b! + b! ;

: parse ( char -- )
  begin key? invert if read then key 32 = if advance repeat
  0 'buffer b!
  begin
    key? invert if read then key over = invert
  if
    key accumulate advance
  repeat
  drop ;

: word 32 parse 'buffer b@ 63 u< invert if 63 'buffer b! then ;

: digit? ( char -- u bool ) [char] 0 - 9 over <
  if [ char A char 0 - 10 - ] literal - dup 10 < or then
  dup base @ u< ;

: natural ( addr u1 -- u2 u3 ) push 0 pop
  begin
    push over b@ digit? pop dup push and
  if
    push base @ * pop + push 1+ pop pop 1- 
  repeat
  drop nip pop ;

: number ( addr u1 -- n u2 ) over b@ [char] - xor
  if natural ret then push 1+ pop 1- natural push negate pop ;

: find ( -- 0 | addr ) latest
  begin
    @ dup 0= over
    if
      over cell + b@ 127 and 'buffer b@ =
      if drop dup [ cell 1+ ] literal + 'buffer count same? then
    then
  until ;

: save 'buffer here @ over b@ 1+ dup aligned here @ + here ! bmove ;

: cfa ( addr -- ) cell + count 63 and + aligned ;

: , ( x -- ) here @ dup cell + here ! ! ; immediate

: [  0 state ! ; immediate
: ] -1 state ! ; immediate

: : postpone ] latest @ here @ latest ! postpone , word save
  lit ' docolon [ @ ] , postpone , ; immediate

: ; hidden lit ret postpone , postpone [ ; hidden immediate

: ' ( -- 0 | xt ) word find dup if cfa then ; immediate

: postpone hidden postpone ' postpone , ; hidden immediate

: literal ( x -- ) lit lit postpone , postpone , ; immediate

: interpret word find dup
  if
    dup cell + b@ 128 and state @ invert or
    if cfa execute ret then
    cfa postpone , ret
  then
  drop 'buffer count number if drop 'buffer count type [char] ? emit ret then
  state @ if postpone literal then ;

: main begin interpret write again [ main
