# Avocado
Being developed using nasm for Linux and macOS on x86-64 architecture.

Tokens get compiled after each newline. Error messages get displayed and line gets flushed upon an invalid token.

Compiled code gets executed after each semicolon. Anything after the semicolon but before the following newline will not be interpreted.

Error reporting:
* A word followed by a question mark means it is not found in the vocabulary and not a literal.
* A literal followed by an exclamation mark means the cell overflowed while converting.
