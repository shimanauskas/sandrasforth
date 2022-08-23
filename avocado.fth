: immediate last @ cell + cell + dup b@ 128 or over b! drop ; immediate

: begin top @ ; immediate
: until lit 0jump postpone , postpone , ; immediate

: char word buffer 1+ b@ ; immediate
: ( begin word buffer b@ 1 = buffer 1+ b@ lit char ) , = and until ; immediate

: if ( -- addr ) lit 0jump postpone , top @ 0 postpone , ; immediate
: then ( addr -- ) push top @ pop ! ; immediate

: again ( addr1 addr2 -- ) push lit jump postpone , postpone , top @ pop ! ;
  immediate

: [ ( -- ) top @ here ! 0 state ! ; immediate
: ] ( -- ) postpone apply -1 state ! ; immediate

: variable ( -- ) postpone : lit var postpone , 0 postpone , postpone ; ;
  immediate

: dec ( -- ) 10 base ! ; immediate
: hex ( -- ) 16 base ! ; immediate
