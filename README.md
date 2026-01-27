# sandrasForth

A public-domain Forth for Linux on x86-64.

It is written mostly in (indirect-)threaded code. There is no limit on the
number of primitives, however, each primitive should be kept small.

Since .text and .data are not mixed, CPU caches stay clean.

## How to run

If you're on a Debian-based Linux distribution, first install `binutils` and
`make` using these commands:

	sudo apt update
	sudo apt install binutils make

Navigate to `sandrasforth` directory, then, to build, issue:

	make

Or, you can build and run in one go using:

	make run

You can exit sandrasForth by pressing Control + D, or:

	bye

If you choose the latter, press Enter an extra time to return to your shell.

## Errors

Upon a word not found, sandrasForth outputs it, followed by a question mark.

sandrasForth will compile a definition without the words not found.

If sandrasForth crashes while defining a word, it most likely ran out of
statically allocated memory.
