avocado-macos: avocado.s
	echo "%define MACOS 1" > platform.s
	nasm -o avocado-macos.o -f macho64 avocado.s
	ld -o avocado-macos -e start -static avocado-macos.o

avocado-linux: avocado.s
	echo "%define LINUX 1" > platform.s
	nasm -o avocado-linux.o -f elf64 avocado.s
	ld -o avocado-linux -e start -static avocado-linux.o

clean:
	rm -f avocado-linux avocado-macos avocado-linux.o avocado-macos.o platform.s
