: immediate last @ cell + cell + dup b@ 128 or over b! drop ; immediate

: [ top @ here ! 0 state ! ; immediate
: ] postpone apply -1 state ! ; immediate

: begin top @ ; immediate

: if lit 0jump postpone , top @ 0 postpone , ; immediate
: then push top @ pop ! ; immediate

: repeat push lit jump postpone , postpone , top @ pop ! ; immediate
: until lit 0jump postpone , postpone , ; immediate

: char word [ buffer 1+ ] literal b@ ; immediate

: ( begin word [ buffer ] literal b@ 1 =
  [ buffer 1+ ] literal b@ char ) literal = and until ; immediate

: variable ( -- ) postpone : lit var postpone , 0 postpone , postpone ; ;
  immediate

: dec ( -- ) 10 base ! ; immediate
: hex ( -- ) 16 base ! ; immediate

: digit ( u -- char ) dup 10 u<
  if char 0 literal + ; then [ char A 10 - ] literal + ;

: hold ( addr1 u1 byte -- addr2 u2 ) push push 1- pop over pop over b! drop 1+ ;

: . ( n -- ) dup 0< if char - literal emit neg then
  ( Fallthrough! )

: u. ( u -- ) push [ buffer 256 + ] literal 0 pop
  begin 0 base @ / push digit hold pop dup 0= until
  drop type ;
