: words latest begin @ dup if dup cell + count 63 and type space repeat drop ;

: forget word find dup if dup here ! @ latest ! else drop then ;
