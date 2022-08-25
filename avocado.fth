: immediate last @ cell + cell + dup b@ 128 or over b! drop ; immediate

: [ top @ here ! 0 state ! ; immediate
: ] postpone apply -1 state ! ; immediate

: begin top @ ; immediate

: if lit 0jump postpone , top @ 0 postpone , ; immediate
: then push top @ pop ! ; immediate

: repeat push lit jump postpone , postpone , top @ pop ! ; immediate
: until lit 0jump postpone , postpone , ; immediate

: char word [ ' buffer 1+ ] literal b@ ; immediate

: ( begin word ' buffer literal b@ 1 =
  [ ' buffer 1+ ] literal b@ char ) literal = and until ; immediate

: digit ( u -- char ) dup 10 u<
  if char 0 literal + ; then [ char A 10 - ] literal + ;

: variable ( -- ) postpone : lit var postpone , 0 postpone , postpone ; ;
  immediate

variable hld

: hold ( char -- ) hld @ 1- dup hld ! b! ;

: . ( n -- ) dup 0< if char - literal emit neg then
  ( Fallthrough! )

: u. ( u -- ) [ ' buffer 256 + ] literal hld !
  begin base @ /mod push digit hold pop dup 0= until drop
  hld @ [ ' buffer 256 + ] literal over - type ;

: dec ( -- ) 10 base ! ; immediate
: hex ( -- ) 16 base ! ; immediate
