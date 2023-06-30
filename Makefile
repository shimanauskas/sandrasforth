avocado: avocado.S
	$(CC) -o avocado -nostdlib -static avocado.S

run: avocado
	cat avocado.fth compiler.fth tools.fth - | ./avocado

clean:
	rm -f avocado
