;;Chris Busch

;destroys bc; hl+=16*8 ;sprite lines
#DEFINE     hlyinc(addr)  ld hl,(addr)
#defcont     \ ld   bc,16*8
#DEFCONT     \ add  hl,bc
#defcont     \ ld (addr),hl


;destroys bc; hl-=16*8
#define hlydec(addr)  ld hl,(addr) \  ld   bc,$FF80
#defcont \ add  hl,bc \ ld (addr),hl

#define hlxinc(addr)  ld hl,(addr) \  inc  hl \ ld (addr),hl

#define hlxdec(addr)  ld hl,(addr) \ dec  hl \ ld (addr),hl

