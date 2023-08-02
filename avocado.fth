: flag ( x -- flag ) if -1 else 0 then ;

: 0= ( x -- flag ) flag invert ;

:  = ( x1 x2 -- flag ) xor 0= ;

: 0< ( n -- flag ) [ 1 cell 8 * 1- lshift ] literal and flag ;

:  < ( n1 n2 -- flag ) over over xor 0< if drop 0< else - 0< then ;
: u< ( u1 u2 -- flag ) over over xor 0< if nip  0< else - 0< then ;

: whithin ( u1 u2 u3 -- flag ) >r over >r u< invert r> r> u< and ;

: aligned ( x1 -- x2 ) [ cell 1- ] literal + [ cell 1- invert ] literal and ;

: count ( addr1 -- addr2 u ) dup >r 1+ r> c@ ;

: cmove ( addr1 addr2 u -- )
  begin dup if >r over c@ over c! >r 1+ r> 1+ r> 1- repeat nip nip drop ;

: same? ( addr1 addr2 u -- flag )
  begin dup >r >r over c@ over c@ = r> and if >r 1+ r> 1+ r> 1- repeat
  r> nip nip 0= ;

: write 1 'output count sys-write syscall drop 0 'output c! ;

: bye write 0 dup dup sys-exit syscall [ reveal

: read 0 [ 'input 1+ ] literal 255 sys-read syscall dup 0=
  if bye then 'input c! [ 'input 1+ ] literal in ! ;

: refill 0 'line c! [ 'line 1+ ] literal mark !
  begin
    'input count + in @ = if read then
    in @ c@ in @ 1+ in ! dup 'line count dup 1+ 'line c! + c!
    10 = 'line c@ 255 = or
  until ;

: key? ( -- flag ) mark @ 'line count + u< ;
: key  ( -- char ) mark @ c@ dup 10 = if drop 32 then ;

: advance mark @ 1+ mark ! ;

: emit ( char -- ) 'output count + c!
  'output c@ 1+ dup 'output c! 255 = if write then ;

: type ( addr u -- ) begin dup if >r dup c@ emit 1+ r> 1- repeat nip drop ;

: accumulate ( char -- ) 'buffer count dup 1+ 'buffer c! + c! ;

: parse ( char -- ) 0 'buffer c!
  begin key? invert if drop exit then key 32 = if advance repeat
  begin
    key? invert if refill then key over = invert
  if
    key accumulate advance
  repeat
  drop ;

: word 32 parse 'buffer c@ [ f-immediate 1- ] literal u< invert
  if [ f-immediate 1- ] literal 'buffer c! then ;

: save 'buffer here @ over c@ 1+ dup aligned here @ + here ! cmove ;

: digit? ( char -- u flag ) [char] 0 - 9 over <
  if [ char A char 0 - 10 - ] literal - dup 10 < or then
  dup base @ u< ;

: natural ( addr u1 -- u2 u3 ) >r 0 r>
  begin
    >r over c@ digit? r> dup >r and
  if
    >r base @ * r> + >r 1+ r> r> 1-
  repeat
  drop nip r> ;

: number ( addr u1 -- n u2 ) over c@ [char] - =
  if >r 1+ r> 1- natural >r negate r> else natural then ;

: find ( -- 0 | addr ) latest
  begin
    @ dup 0= over
    if
      over cell + c@ [ f-immediate 1- ] literal and 'buffer c@ =
      if drop dup [ cell 1+ ] literal + 'buffer count same? then
    then
  until ;

: >code ( addr1 -- addr2 )
  cell + count [ f-immediate 1- ] literal and + aligned ;

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
    word 'buffer c@
    if
      find dup
      if
        dup cell + c@ f-immediate and state @ invert or
        if >code execute else >code , then
      else
        drop 'buffer count number
        if
          drop 'buffer count type [char] ? emit
        else
          state @ if postpone literal then
        then
      then
      write
    else
      exit
    then
  again [ reveal

: main begin refill interpret again [ reveal main
