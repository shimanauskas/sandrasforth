# Avocado

A Forth for Linux and macOS on x86-64.

Avocado began as an attempt to write a Forth mostly in itself.

Large part of Avocado is threaded code. There is no limit on the number of primitives used, however, each primitive should contain only a handful of assembly instructions.

## The IO System

There's a pair of buffers for input and output. `accept` reads input and places it in the `input` buffer. Each invocation of `key` then accesses the buffer and reads a character from it onto the stack. Then, `emit` can take that character and put it in the `output` buffer, which we can `flush`.

`input` and `output` buffers are circular.

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
