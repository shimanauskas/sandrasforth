Avocado-Linux: Avocado.s
	echo "%define LINUX 1" > platform.s
	nasm -o Avocado-Linux.o -f elf64 Avocado.s
	ld -o Avocado-Linux -e start -static Avocado-Linux.o

Avocado-macOS: Avocado.s
	echo "%define MACOS 1" > platform.s
	nasm -o Avocado-macOS.o -f macho64 Avocado.s
	ld -o Avocado-macOS -e start -static Avocado-macOS.o

clean:
	rm -f Avocado-Linux Avocado-macOS Avocado-Linux.o Avocado-macOS.o platform.s
