: bool ( x -- bool ) if -1 ret then 0 ;

: 0= ( x -- bool ) bool not ;

:  = ( x1 x2 -- bool ) xor 0= ;

: 0< ( n -- bool ) [ 1 8 cells 1- lshift ] literal and bool ;

:  < ( n1 n2 -- bool ) over over xor 0< if drop 0< ret then - 0< ;
: u< ( u1 u2 -- bool ) over over xor 0< if nip  0< ret then - 0< ;

: whithin ( u1 u2 u3 -- bool ) push over push u< not pop pop u< and ;

: aligned ( x1 -- x2 ) [ cell 1- ] literal + [ cell 1- not ] literal and ;

: string ( addr1 -- addr2 u ) dup push 1+ pop b@ ;

: bmove ( addr1 addr2 u -- )
  begin dup if push over b@ over b! push 1+ pop 1+ pop 1- repeat
  nip nip drop ;

: same? ( addr1 addr2 u -- bool )
  begin dup push push over b@ over b@ = pop and if push 1+ pop 1+ pop 1- repeat
  pop nip nip 0= ;

: write 1 'output string sys-write syscall drop 0 'output b! ;

: bye write 0 dup dup sys-exit syscall ( We never return. )

: read 0 [ 'input 1+ ] literal 255 sys-read syscall dup
  if 'input b! [ 'input 1+ ] literal mark ! ret then bye

: key? ( -- bool ) mark @ 'input string + u< ;
: key  ( -- char ) mark @ b@ ;

: advance mark @ 1+ mark ! ;

: emit ( char -- ) 'output string + b!
  'output b@ 1+ dup 'output b! 255 xor if ret then write ;

: type ( addr u -- ) begin dup if push dup b@ emit 1+ pop 1- repeat nip drop ;

: accumulate ( char -- ) 'buffer string dup 1+ 'buffer b! + b! ;

: skip
  begin key? not if read then key char ! u< key 10 xor and if advance repeat ;

: word? skip 0 'buffer b! key 10 xor
  if
    begin
      key? not if read then key dup char ! u< not 'buffer b@ 63 u< and
    if
      accumulate advance
    repeat
    drop
  then ;

: word begin word? 'buffer b@ 0= if advance repeat ;

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

: number ( addr u1 -- n u2 ) over b@ char - xor
  if natural ret then push 1+ pop 1- natural push negate pop ;

: find ( -- 0 | addr ) last
  begin
    @ dup 0= over
    if
      over nfa + b@ 127 and 'buffer b@ =
      if drop dup [ nfa 1+ ] literal + 'buffer string same? then
    then
  until ;

: collision top @ 'guard u< not
  if [ last @ nfa + ] literal string type bye then ;

: save 'buffer top @ over b@ 1+ dup aligned top @ + top ! collision
  bmove commit ;

: , ( x -- ) top  @ dup cell + top  ! ! collision ; immediate

: commit top @ here ! ;

: apply state @
  if commit ret then lit ret postpone , here @ dup top ! execute ;

: [ commit 0 state ! ; immediate
: ] apply -1 state ! ; immediate

: : postpone ] last @ top @ last ! postpone , top @ push 0 postpone ,
  word save top @ pop ! ; immediate

: ; hidden lit ret postpone , postpone [ ; hidden immediate

: ' ( -- 0 | xt ) word find dup if cell + @ then ; immediate

: postpone hidden postpone ' lit call postpone , postpone , ; hidden immediate

: literal ( x -- ) lit lit postpone , postpone , ; immediate

: interpret word? 'buffer b@
  if
    find dup
    if
      cell + dup cell + b@ 128 and
      if @ execute jump ' interpret , then
      @ dup code-start code-end within not
      if lit call postpone , then
      postpone , jump ' interpret ,
    then
    drop 'buffer string number
    if drop 'buffer string type char ? emit ret then
    postpone literal jump ' interpret ,
  then ;

: main begin interpret apply advance write again [ main ]
