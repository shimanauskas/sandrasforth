#!/bin/sh
rm -rf Avocado Avocado.o
nasm -f macho64 -o Avocado.o Avocado.s
ld -o Avocado -macosx_version_min 10.15 -static -no_pie Avocado.o
./Avocado
