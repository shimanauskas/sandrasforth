sandrasforth: sandrasforth.S
	as -o sandrasforth.o sandrasforth.S
	ld -o sandrasforth sandrasforth.o

run: sandrasforth
	cat core.fth sandrasforth.fth tools.fth - | ./sandrasforth

clean:
	rm -f sandrasforth sandrasforth.o
