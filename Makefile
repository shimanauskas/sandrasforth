avocado: avocado.S
	$(CC) -o avocado -nostdlib -static avocado.S

run: avocado
	cat core.fth avocado.fth tools.fth - | ./avocado

clean:
	rm -f avocado
