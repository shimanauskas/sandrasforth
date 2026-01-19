# sandrasForth

A public-domain Forth for Linux on x86-64.

It is written mostly in (indirect-)threaded code. There is no limit on the
number of primitives, however, each primitive should be kept small.

Since .text and .data are not mixed, CPU caches stay clean.

## Requirements

* binutils
* make

## Errors

Upon a word not found, sandrasForth outputs it, followed by a question mark.

sandrasForth will compile a definition without the words not found.

If sandrasForth crashes while defining a word, it most likely ran out of
statically allocated memory.
