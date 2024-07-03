kernel: kernel.S
	$(CC) -o kernel -nostdlib -static kernel.S

run: kernel
	cat core.fth kernel.fth tools.fth - | ./kernel

clean:
	rm -f kernel
