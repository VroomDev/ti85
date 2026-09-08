# Crunch VIC-20 (ca65 / ld65, unexpanded)

CC65   ?= $(USERPROFILE)/cc65
CA65   := $(CC65)/bin/ca65
LD65   := $(CC65)/bin/ld65
CFG    := vic20-crunch.cfg

OBJS := build/loadaddr.o build/exehdr.o build/startup.o build/main.o build/gfx.o build/map.o build/level.o build/input.o build/player.o build/sound.o

.PHONY: all clean run

all: crunch.prg

build:
	mkdir -p build

build/%.o: src/%.s src/game.inc src/vic.inc | build
	$(CA65) -t vic20 -I src -o $@ $<

crunch.prg: $(OBJS) $(CFG)
	$(LD65) -C $(CFG) -o $@ -m build/crunch.map $(OBJS)

clean:
	rm -f build/*.o crunch.prg build/crunch.map

run: crunch.prg
	$(USERPROFILE)/GTK3VICE-3.10-win64/bin/xvic.exe -ntsc -autostart crunch.prg
