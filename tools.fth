: words latest
  begin
    @ dup
  if
    dup cell + count [ f-immediate 1- ] literal and type bl emit
  repeat
  drop ;

: prompt begin ." # " refill interpret again [ reveal prompt
