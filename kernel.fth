: flag ( x -- flag ) if -1 else 0 then ;

: 0= ( x -- flag ) flag invert ;

:  = ( x1 x2 -- flag ) xor 0= ;

: 0< ( n -- flag ) [ 1 cell 8 * 1- lshift ] literal and flag ;

:  < ( n1 n2 -- flag ) over over xor 0< if drop 0< else - 0< then ;
: u< ( u1 u2 -- flag ) over over xor 0< if nip  0< else - 0< then ;

: whithin ( u1 u2 u3 -- flag ) >r over >r u< invert r> r> u< and ;

: c, ( char -- ) here @ dup 1+     here ! c! ;
:  , ( x -- )    here @ dup cell + here !  ! ;

: aligned ( x1 -- x2 ) [ cell 1- ] literal + [ cell 1- invert ] literal and ;

: count ( addr1 -- addr2 u ) 1+ dup 1- c@ ;

: cmove ( addr1 addr2 u -- )
  begin dup if >r over c@ over c! >r 1+ r> 1+ r> 1- repeat nip nip drop ;

: s, ( addr u -- )
  dup c, dup >r >r here @ r> cmove r> here @ + aligned here ! ;

: s= ( addr1 u1 addr2 u2 -- flag ) >r over >r nip r> r> over =
  if
    begin dup >r >r over c@ over c@ = r> and if >r 1+ r> 1+ r> 1- repeat
    r> nip nip 0=
  else
    nip nip drop 0
  then ;

: bye 0 dup dup sys-exit syscall [ reveal

: key  ( -- char ) 0 here @ 1 sys-read syscall 0= if bye then here @ c@ ;

: emit ( char -- ) here @ c! 1 here @ 1 sys-write syscall drop ;

: refill 0 'input c! 0 >in !
  begin
    key dup dup lf = if drop bl then
    'input count + c! 'input c@ 1+ 'input c! lf = 'input c@ 255 = or
  until ;

: type ( addr u -- ) begin dup if >r dup c@ emit 1+ r> 1- repeat nip drop ;

: parse ( char -- addr u ) >r >in @ dup
  begin
    dup 'input c@ u< over [ 'input 1+ ] literal + c@ r> dup >r = invert and
  if
    1+
  repeat
  r> drop dup 1+ >in ! over - >r [ 'input 1+ ] literal + r> ;

: word ( char - addr ) >r 'buffer >in @
  begin
    dup 'input c@ u< over [ 'input 1+ ] literal + c@ r> dup >r = and
  if
    1+
  repeat
  >in ! r> parse dup [ f-immediate 1- ] literal u< invert
  if drop [ f-immediate 1- ] literal then
  >r over r> over c! count cmove ;

: c>number ( char -- n ) [char] 0 - 9 over <
  if [ char A char 0 - 10 - ] literal - dup 10 < or then ;

: u>number ( 0 addr u1 -- u2 addr2 u3 )
  begin
    dup >r >r dup >r c@ c>number r> over base @ u< r> and
  if
    >r >r base @ * r> + r> 1+ r> 1-
  repeat
  nip r> ;

: >number ( 0 addr1 u1 -- n addr2 u2 ) over c@ [char] - =
  if >r 1+ r> 1- u>number >r >r negate r> r> else u>number then ;

: >code ( addr1 -- addr2 )
  cell + count [ f-immediate 1- ] literal and + aligned ;

: find ( addr -- addr 0 | xt 1 | xt -1 ) dup latest >r
  begin
    r> @ dup >r 0= dup invert
    if
      drop dup count r> dup >r cell + count [ f-immediate 1- ] literal and s=
    then
  until
  drop r> dup
  if
    nip dup cell + c@ f-immediate and state @ invert or
    if 1 else -1 then >r >code r>
  then ;

: [  0 state ! ; immediate
: ] -1 state ! ;

: : here @ current ! latest @ , bl word count s, [ ' enter @ ] literal , ] ;

: reveal current @ latest ! ;

: ; ['] exit , reveal postpone [ ; immediate

: ' ( -- 0 | xt ) bl word find dup if drop else nip then ;

: literal ( x -- ) lit lit , , ; immediate

: interpret
  begin
    bl word dup c@
    if
      find dup
      if
        0< if , else execute then
      else
        drop 0 over count >number
        if
          drop drop count type [char] ? emit
        else
          drop nip state @ if postpone literal then
        then
      then
    else
      drop ;
    then
  again

: main begin refill interpret again [ reveal main
