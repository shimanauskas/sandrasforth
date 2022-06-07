avocado: avocado.S
	$(CC) -o avocado -nostdlib -static -e _start avocado.S

run: avocado
	./avocado

clean:
	rm -f avocado
