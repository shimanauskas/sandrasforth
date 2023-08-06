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

: count ( addr1 -- addr2 u ) dup >r 1+ r> c@ ;

: cmove ( addr1 addr2 u -- )
  begin dup if >r over c@ over c! >r 1+ r> 1+ r> 1- repeat nip nip drop ;

: same? ( addr1 addr2 u -- flag )
  begin dup >r >r over c@ over c@ = r> and if >r 1+ r> 1+ r> 1- repeat
  r> nip nip 0= ;

: bye 0 dup dup sys-exit syscall [ reveal

: key  ( -- char ) 0 here @ 1 sys-read syscall 0= if bye then here @ c@ ;

: emit ( char -- ) here @ c! 1 here @ 1 sys-write syscall drop ;

: refill 0 'input c! 0 >in !
  begin
    key dup dup 10 = if drop 32 then
    'input count + c! 'input c@ 1+ 'input c! 10 = 'input c@ 255 = or
  until ;

: type ( addr u -- ) begin dup if >r dup c@ emit 1+ r> 1- repeat nip drop ;

: parse ( char -- addr u ) >r >in @
  begin
    dup 'input c@ = if r> drop dup >in ! 'input + 0 exit then
    1+ dup 'input + c@ 32 = invert
  until
  dup
  begin 1+ dup 'input + c@ r> dup >r = until
  r> drop dup >in ! over - >r 'input + r> ;

: save dup c, dup >r >r here @ r> cmove r> here @ + aligned here ! ;

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

: find ( -- 0 | addr ) >r >r latest
  begin
    @ dup 0= over
    if
      over cell + c@ [ f-immediate 1- ] literal and r> r> over over >r >r nip =
      if drop dup [ cell 1+ ] literal + r> r> over over >r >r same? then
    then
  until
  r> r> drop drop ;

: >code ( addr1 -- addr2 )
  cell + count [ f-immediate 1- ] literal and + aligned ;

: [  0 state ! ; immediate
: ] -1 state ! ;

: : ] here @ current ! latest @ , 32 parse save [ ' enter @ ] literal , ;

: reveal current @ latest ! ;

: ; ['] exit , reveal postpone [ ; immediate

: ' ( -- 0 | xt ) 32 parse find dup if >code then ;

: literal ( x -- ) lit lit , , ; immediate

: interpret
  begin
    32 parse dup
    if
      over over find dup
      if
        nip nip dup cell + c@ f-immediate and state @ invert or
        if >code execute else >code , then
      else
        drop over over number
        if
          drop type [char] ? emit
        else
          nip nip state @ if postpone literal then
        then
      then
    else
      drop drop ;
    then
  again

: main begin refill interpret again [ reveal main
