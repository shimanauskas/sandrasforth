: [ top @ here ! -1 state ! ; immediate
: ] postpone apply 0 state ! ; immediate

: begin top @ ; immediate

: if lit ?jump postpone , top @ 0 postpone , ; immediate
: then push top @ pop ! ; immediate

: repeat push lit jump postpone , postpone , top @ pop ! ; immediate
: until lit ?jump postpone , postpone , ; immediate

: char word [ 'buffer 1+ ] literal b@ ; immediate

: ( begin word [ 'buffer ] literal b@ 1 =
  [ 'buffer 1+ ] literal b@ char ) literal = and until ; immediate

: digit ( u -- char ) dup 10 u<
  if char 0 literal + ; then [ char A 10 - ] literal + ;

: variable postpone : lit var postpone , 0 postpone , postpone ; ; immediate

variable hld

: hold ( char -- ) hld @ 1- dup hld ! b! ;

: u. ( u -- ) [ 'buffer 256 + ] literal hld !
  begin 0 base @ um/mod push digit hold pop dup 0= until drop
  hld @ [ 'buffer 256 + ] literal over - type ;

: . ( n -- ) dup 0< if char - literal emit neg then u. ;

: bina  2 base ! ; immediate
: deci 10 base ! ; immediate
: hexa 16 base ! ; immediate

: space 32 emit ;

: cells ( u1 -- u2 ) [ cell ] literal um* drop ;

: words last
  begin @ dup if dup [ 2 cells ] literal + string 127 and type space repeat
  drop ;
