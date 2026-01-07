sandrasforth: sandrasforth.S
	cc -o sandrasforth -nostdlib -static sandrasforth.S

run: sandrasforth
	cat core.fth sandrasforth.fth tools.fth - | ./sandrasforth

clean:
	rm -f sandrasforth
