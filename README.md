# Avocado

A Forth for Linux and macOS on x86-64.

Avocado is written mostly in (direct-)threaded code. There is no limit on the amount of primitives, however, each primitive should be kept small.

Since .text and .data are not mixed, CPU caches stay clean.

For further efficiency, Avocado has buffered I/O.

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
