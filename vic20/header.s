; BASIC stub at $1201: SYS 8192 ($2000 = cc65 STARTUP)
        .export         __LOADADDR__ : absolute = 1
        .export         __EXEHDR__   : absolute = 1

.segment        "LOADADDR"
        .addr           $1201

.segment        "EXEHDR"
        .addr           Next
        .word           10
        .byte           $9E
        .byte           "8192"
        .byte           $00
Next:   .addr           $0000
