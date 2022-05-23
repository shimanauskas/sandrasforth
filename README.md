# Avocado

Forth interpreter for Linux and macOS on x86-64.

Large part of Avocado is threaded code. There is no limit on the number of primitives used, however, each primitive should contain only a handful of assembly instructions.

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
