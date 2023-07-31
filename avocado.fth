: bool ( x -- bool ) if -1 else 0 then ;

: 0= ( x -- bool ) bool invert ;

:  = ( x1 x2 -- bool ) xor 0= ;

: 0< ( n -- bool ) [ 1 cell 8 * 1- lshift ] literal and bool ;

:  < ( n1 n2 -- bool ) over over xor 0< if drop 0< else - 0< then ;
: u< ( u1 u2 -- bool ) over over xor 0< if nip  0< else - 0< then ;

: whithin ( u1 u2 u3 -- bool ) push over push u< invert pop pop u< and ;

: aligned ( x1 -- x2 ) [ cell 1- ] literal + [ cell 1- invert ] literal and ;

: count ( addr1 -- addr2 u ) dup push 1+ pop c@ ;

: cmove ( addr1 addr2 u -- )
  begin dup if push over c@ over c! push 1+ pop 1+ pop 1- repeat
  nip nip drop ;

: same? ( addr1 addr2 u -- bool )
  begin dup push push over c@ over c@ = pop and if push 1+ pop 1+ pop 1- repeat
  pop nip nip 0= ;

: write 1 'output count sys-write syscall drop 0 'output c! ;

: bye write 0 dup dup sys-exit syscall [ reveal

: read 0 [ 'input 1+ ] literal 255 sys-read syscall dup 0=
  if bye then 'input c! [ 'input 1+ ] literal mark ! ;

: key? ( -- bool ) mark @ 'input count + u< ;
: key  ( -- char ) mark @ c@ dup 10 = if drop 32 then ;

: advance mark @ 1+ mark ! ;

: emit ( char -- ) 'output count + c!
  'output c@ 1+ dup 'output c! 255 = if write then ;

: type ( addr u -- ) begin dup if push dup c@ emit 1+ pop 1- repeat nip drop ;

: accumulate ( char -- ) 'buffer count dup 1+ 'buffer c! + c! ;

: parse ( char -- )
  begin key? invert if read then key 32 = if advance repeat
  0 'buffer c!
  begin
    key? invert if read then key over = invert
  if
    key accumulate advance
  repeat
  drop ;

: word 32 parse 'buffer c@ [ immediate-flag 1- ] literal u< invert
  if [ immediate-flag 1- ] literal 'buffer c! then ;

: digit? ( char -- u bool ) [char] 0 - 9 over <
  if [ char A char 0 - 10 - ] literal - dup 10 < or then
  dup base @ u< ;

: natural ( addr u1 -- u2 u3 ) push 0 pop
  begin
    push over c@ digit? pop dup push and
  if
    push base @ * pop + push 1+ pop pop 1- 
  repeat
  drop nip pop ;

: number ( addr u1 -- n u2 ) over c@ [char] - =
  if push 1+ pop 1- natural push negate pop else natural then ;

: find ( -- 0 | addr ) latest
  begin
    @ dup 0= over
    if
      over cell + c@ [ immediate-flag 1- ] literal and 'buffer c@ =
      if drop dup [ cell 1+ ] literal + 'buffer count same? then
    then
  until ;

: save 'buffer here @ over c@ 1+ dup aligned here @ + here ! cmove ;

: >code ( addr1 -- addr2 )
  cell + count [ immediate-flag 1- ] literal and + aligned ;

: , ( x -- ) here @ dup cell + here ! ! ;

: [  0 state ! ; immediate
: ] -1 state ! ;

: : ] here @ current ! latest @ , word save [ ' do: @ ] literal , ;

: reveal current @ latest ! ;

: ; [ ' exit ] literal , reveal postpone [ ; immediate

: ' ( -- 0 | xt ) word find dup if >code then ;

: literal ( x -- ) lit lit , , ; immediate

: interpret
  begin
    word find dup
    if
      dup cell + c@ immediate-flag and state @ invert or
      if
        >code execute
      else
        >code ,
      then
    else
      drop 'buffer count number
      if
        drop 'buffer count type [char] ? emit
      else
        state @ if postpone literal then
      then
    then
    write
  again [ reveal interpret
