: immediate last @ 16 + dup b@ 128 or over b! drop ; immediate

: begin top @ ; immediate
: if lit 0jump postpone , top @ 0 postpone , ; immediate
: then push top @ pop ! ; immediate
: again push lit jump postpone , postpone , top @ pop ! ; immediate

: dec 10 base ! ; immediate
: hex 16 base ! ; immediate
