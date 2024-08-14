SQUOT = TEXT_MEM2+160
SREM = TEXT_MEM2+161

MUL16:
 ld   c, l    ;BC = MULTIPLIER
 ld   b, h
 ld   hl, 0   ;PRODUCT = 0
 ld   a, 15   ;COUNT = BIT LENGTH - 1
 ;Shift and Add-Algorithm
 ;If MSB of Multiplier is 1, add multipliand to prtial
 ;product. Shift partial product, multiplier left 1 bit
MLP:
 sla  e
 rl   d
 jr   nc, MLP1
 add  hl, bc
MLP1:
 add  hl, hl
 dec  a
 jr   nz, MLP

 or   d
 ret  p
 add  hl, bc
 ret

;-----------------------------------------------------------------------------
;SDIV16: signed division, uses UDIV16
;-----------------------------------------------------------------------------
SDIV16:
 push  bc
 ld    a, h
 ld    (SREM), a
 xor   d
 ld    (SQUOT), a

 bit   7, d
 jr    z, CheckDE
 or    a
 sub   a
 sub   e
 ld    e, a
 sbc   a, a
 sub   d
 ld    d, a

CheckDE:
 bit   7, h
 jr    z, DoDiv
 or    a
 sub   a
 sub   l
 ld    l, a
 sbc   a, a
 sub   h
 ld    h, a

DoDiv:
 CALL_(UDIV16)

 ld    a, (SQUOT)
 bit   7, a
 jr    z, DoRem    ;!
 or    a
 sub   a
 sub   l
 ld    l, a
 sbc   a, a
 sub   h
 ld    h, a

DoRem:
 pop   bc
 ret

;-----------------------------------------------------------------------------
;UDIV16: divides HL trough DE
; quotient in HL
; carry = 0
;-----------------------------------------------------------------------------
UDIV16:

Divide:
 ld    c, l
 ld    a, h
 ld    hl, 0       ;hl = remainder
 ld    b, 16       ;16 bits in dividend
 or    a           ;clear carry

DivLoop:
 rl    c
 rla
 rl    l
 rl    h

 push  hl
 sbc   hl, de
 ccf

 jr    c, Drop
 ex    (sp), hl
Drop:
 inc   sp
 inc   sp
 djnz  DivLoop

 ex    de, hl
 rl    c
 ld    l, c
 rla
 ld    h, a
 or    a
 ret