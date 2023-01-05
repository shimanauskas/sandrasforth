: words last
  begin @ dup if dup [ 2 cells ] literal + string 127 and type space repeat
  drop ;

" # "

: main literal string type flush accept postpone interpret postpone apply main ;
  immediate main
