ROM := rom/coindash.sfc

.PHONY: all graphics clean run

all: $(ROM)

$(ROM): src/main.asm src/graphics_data.asm
	cd src && acme --cpu 65816 -f plain -o ../$(ROM) main.asm
	python3 tools/fix_checksum.py $(ROM)

graphics:
	python3 tools/gen_graphics.py

clean:
	rm -f $(ROM)

run: $(ROM)
	retroarch -L /usr/lib/x86_64-linux-gnu/libretro/snes9x_libretro.so $(ROM)
