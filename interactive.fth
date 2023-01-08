: words last
  begin @ dup if dup nfa + string length and type space repeat
  drop ;

: main " # " literal string type flush accept interpret apply recurse ;
  immediate main
