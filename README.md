# Avocado
A Forth-like system for Linux and macOS on x86-64.

The goal for Avocado is to become self-hosting. For now it can be used as a postfix calculator.

## Requirements

Requires make, nasm and ld to build.

No more dependencies, other than a few system calls.

## Usage

Terminate input with a semicolon to get it interpreted.

Error reporting:
* A word followed by a question mark means it is not found in the vocabulary and not a literal.
* A literal followed by an exclamation mark means the cell overflowed while converting.
