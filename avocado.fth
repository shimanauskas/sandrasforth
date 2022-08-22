: immediate last @ cell + cell + dup b@ 128 or over b! drop ; immediate

: begin top @ ; immediate
: until lit 0jump postpone , postpone , ; immediate

: char word buff 1+ b@ ; immediate
: ( begin word buff b@ 1 = buff 1+ b@ lit char ) , = and until ; immediate

: if ( c: -- addr ) lit 0jump postpone , top @ 0 postpone , ; immediate
: then ( c: addr -- ) push top @ pop ! ; immediate

: again ( c: addr1 addr2 -- )
  push lit jump postpone , postpone , top @ pop ! ; immediate

: variable postpone : lit var postpone , 0 postpone , postpone ; ; immediate

variable temporary

: [ postpone apply state @ temporary ! 0 state ! ; immediate
: ] postpone apply temporary @ state ! ; immediate

: dec ( -- ) 10 base ! ; immediate
: hex ( -- ) 16 base ! ; immediate
