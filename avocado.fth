: immediate last @ cell + cell + dup b@ 128 or over b! drop ; immediate

: begin top @ ; immediate
: until lit 0jump postpone , postpone , ; immediate

: char word buffer 1+ b@ ; immediate
: ( begin word buffer b@ 1 = buffer 1+ b@ lit char ) , = and until ; immediate

: if ( -- addr ) lit 0jump postpone , top @ 0 postpone , ; immediate
: then ( addr -- ) push top @ pop ! ; immediate

: repeat ( addr1 addr2 -- ) push lit jump postpone , postpone , top @ pop ! ;
  immediate

: [ ( -- ) top @ here ! 0 state ! ; immediate
: ] ( -- ) postpone apply -1 state ! ; immediate

: variable ( -- ) postpone : lit var postpone , 0 postpone , postpone ; ;
  immediate

: dec ( -- ) 10 base ! ; immediate
: hex ( -- ) 16 base ! ; immediate

: digit ( u -- char ) dup 10 u<
  if lit char 0 , + ; then lit [ char A 10 - ] , + ;

: hold ( addr1 u1 byte -- addr2 u2 ) push push 1- pop over pop over b! drop 1+ ;

: . ( n -- ) dup 0< if lit char - , emit neg then
  ( Fallthrough! )

: u. ( u -- ) push buffer 256 + 0 pop
  begin 0 base @ / push digit hold pop dup 0= until
  drop type ;
