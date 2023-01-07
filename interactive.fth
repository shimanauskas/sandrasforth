: words last
  begin @ dup if dup [ 2 cells ] literal + string length and type space repeat
  drop ;

: main " # " literal string type flush accept interpret apply recurse ;
  immediate main
