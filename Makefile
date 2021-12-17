avocado: avocado.S
	$(CC) -o avocado -nostdlib -static -e main avocado.S

run: avocado
	./avocado

clean:
	rm -f avocado
