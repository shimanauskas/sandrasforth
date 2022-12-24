: [ top @ here ! -1 state ! ; immediate
: ] postpone apply 0 state ! ; immediate

: begin top @ ; immediate

: if lit ?jump postpone , top @ 0 postpone , ; immediate
: then push top @ pop ! ; immediate

: repeat push lit jump postpone , postpone , top @ pop ! ; immediate
: until lit ?jump postpone , postpone , ; immediate

: variable postpone : lit var postpone , 0 postpone , postpone ; ; immediate

: char begin word [ 'buffer ] literal b@ until
  [ 'buffer 1+ ] literal b@ ; immediate

: ( begin word [ 'buffer ] literal b@ 1 =
  [ 'buffer 1+ ] literal b@ char ) literal = and until ; immediate

: hold ( char -- ) [ 'buffer ] literal @ 1- dup [ 'buffer ] literal ! b! ;

: digit ( u -- char ) dup 10 u<
  if char 0 literal + tail then [ char A 10 - ] literal + ;

: u. ( u -- ) [ 'buffer 256 + ] literal [ 'buffer ] literal !
  begin 0 base @ um/mod push digit hold pop dup 0= until drop
  [ 'buffer ] literal @ [ 'buffer 256 + ] literal over - type ;

: . ( n -- ) dup 0< if char - literal emit negate then u. ;

: bina  2 base ! ; immediate
: deci 10 base ! ; immediate
: hexa 16 base ! ; immediate

: lshift ( x1 u -- x2 ) begin dup if push 2* pop 1- repeat drop ;

: rshift ( x1 u -- x2 ) begin dup if push 2/ pop 1- repeat drop ;

: * ( n1 n2 -- n3 ) um* drop ;

: cells ( n1 -- n2 ) [ cell ] literal * ;

: bool ( x -- bool ) if -1 tail then 0 ;

: 0= ( x -- bool ) bool not ;

:  = ( x1 x2 -- bool ) xor 0= ;

: 0< ( n -- bool ) [ 1 8 cells 1- lshift ] literal and bool ;

:  < ( n1 n2 -- bool ) over over xor 0< if drop 0< tail then - 0< ;

: u< ( u1 u2 -- bool ) over over xor 0< if nip  0< tail then - 0< ;

: whithin ( u1 u2 u3 -- bool ) push over push u< not pop pop u< and ;

: aligned ( x1 -- x2 ) [ cell 1- ] literal + [ cell 1- not ] literal and ;

: string ( addr1 -- addr2 u ) dup push 1+ pop b@ ;

: space 32 emit ;

: words last
  begin @ dup if dup [ 2 cells ] literal + string 127 and type space repeat
  drop ;
