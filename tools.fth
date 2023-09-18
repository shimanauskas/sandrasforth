: words latest
  begin
    @ dup
  if
    dup cell + count [ f-immediate 1- ] literal and type bl emit
  repeat
  drop ;

: marker here @ : ['] lit , , ['] here , ['] ! ,
  latest @ ['] lit , , ['] latest , ['] ! , postpone ; ;

: prompt begin ." # " refill interpret again [ reveal prompt
