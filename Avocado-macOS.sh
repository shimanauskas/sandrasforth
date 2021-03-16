#!/bin/sh
rm -f Avocado Avocado.o
echo "%define MACOS 1" > platform.s
nasm -o Avocado.o -f macho64 Avocado.s
ld -o Avocado -e start -static Avocado.o
./Avocado
