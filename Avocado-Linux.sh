#!/bin/sh
rm -f Avocado Avocado.o
nasm -o Avocado.o -f elf64 Avocado.s
ld -o Avocado -e start -static Avocado.o
./Avocado
