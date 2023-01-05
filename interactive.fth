: words last
  begin @ dup if dup [ 2 cells ] literal + string length and type space repeat
  drop ;

" # "

: main literal string type flush accept postpone interpret postpone apply main ;
  immediate main
