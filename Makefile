.PHONY: run clean

avocado: avocado.S
	$(CC) -o avocado -nostdlib -static -e _start avocado.S

run: avocado
	cat avocado.fth - | ./avocado

clean:
	rm -f avocado
