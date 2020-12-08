#!/bin/sh
rm -f Avocado Avocado.o
nasm -f macho64 -o Avocado.o Avocado.s
ld -o Avocado -static Avocado.o
./Avocado
