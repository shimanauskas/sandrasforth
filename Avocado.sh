#!/bin/sh
rm -f Avocado Avocado.o
nasm -o Avocado.o -f macho64 Avocado.s
ld -o Avocado -static Avocado.o
./Avocado
