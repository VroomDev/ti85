# Crunch Commodore 16 (ca65 / ld65, 16KB)

CC65   ?= $(USERPROFILE)/cc65
CA65   := $(CC65)/bin/ca65
LD65   := $(CC65)/bin/ld65
CFG    := c16-crunch.cfg

OBJS := build/loadaddr.o build/exehdr.o build/startup.o build/main.o build/gfx.o build/map.o build/level.o build/input.o build/player.o build/sound.o

.PHONY: all clean run

all: c16crunch.prg

build:
	mkdir -p build

build/%.o: src/%.s src/game.inc src/c16.inc | build
	$(CA65) -t c16 -I src -o $@ $<

c16crunch.prg: $(OBJS) $(CFG)
	$(LD65) -C $(CFG) -o $@ -m build/crunch.map $(OBJS)

clean:
	rm -f build/*.o c16crunch.prg build/crunch.map

run: c16crunch.prg
	$(USERPROFILE)/GTK3VICE-3.10-win64/bin/xplus4.exe -model c16 -autostart c16crunch.prg
