: words last begin @ dup if dup nfa + string 63 and type space repeat drop ;

: main " # " literal string type flush accept interpret apply main ;
  immediate main
