# Avocado
A Forth-like system for Linux and macOS on x86-64.

Requires make, nasm and ld.

Terminate input with a semicolon to get it interpreted.

Error reporting:
* A word followed by a question mark means it is not found in the vocabulary and not a literal.
* A literal followed by an exclamation mark means the cell overflowed while converting.
