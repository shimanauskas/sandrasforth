: immediate last @ cell + cell + dup b@ 128 or over b! drop ; immediate

: begin top @ ; immediate
: until lit 0jump postpone , postpone , ; immediate

: char word buffer 1+ b@ ; immediate
: ( begin word buffer b@ 1 = buffer 1+ b@ lit char ) , = and until ; immediate

: if ( c: -- addr ) lit 0jump postpone , top @ 0 postpone , ; immediate
: then ( c: addr -- ) push top @ pop ! ; immediate

: again ( c: addr1 addr2 -- )
  push lit jump postpone , postpone , top @ pop ! ; immediate

: [ postpone apply state @ push 0 state ! main pop state ! ; immediate
: ] postpone apply pop pop drop push ; immediate

: variable postpone : lit var postpone , 0 postpone , postpone ; ; immediate

: dec ( -- ) 10 base ! ; immediate
: hex ( -- ) 16 base ! ; immediate
