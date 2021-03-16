#!/bin/sh
rm -f Avocado Avocado.o
echo "%define LINUX 1" > platform.s
nasm -o Avocado.o -f elf64 Avocado.s
ld -o Avocado -e start -static Avocado.o
./Avocado
