avocado: avocado.S
	$(CC) -o avocado -nostdlib -static avocado.S

run: avocado
	cat core.fth avocado.fth tools.fth - | ./avocado

demo: avocado
	cat core.fth demo.fth /dev/random | ./avocado | ffmpeg -y \
	-f rawvideo -video_size 32x32 -pixel_format rgb24 -i pipe: \
	-pred none -vf scale=4096x4096:flags=neighbor -frames:v 1 demo.png

clean:
	rm -f avocado demo.png
