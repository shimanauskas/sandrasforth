# Avocado

A Forth for Linux and macOS on x86-64.

Avocado is written mostly in (indirect-)threaded code. There is no limit on the amount of primitives, however, each primitive should be kept small.

Since .text and .data are not mixed, CPU caches stay clean.

For further efficiency, Avocado has buffered I/O.

There is no prompt.

## Prerequisites

* `make`
* `gcc` or `clang`

## Usage

Build:

	make

Run:

	make run

Quit:

	ctrl^d

Clean:

	make clean

## Errors

Upon a word not found, Avocado outputs it, followed by a question mark.

When Avocado runs out of statically allocated memory, the word `collision` will be printed and Avocado will exit.
