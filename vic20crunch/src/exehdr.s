;; BASIC stub at $1001 — SYS 4109 ($100D)

.segment "EXEHDR"
        .word $100B             ; next BASIC line
        .word 2026              ; line number
        .byte $9E               ; SYS token
        .byte "4109"            ; SYS 4109 = $100D
        .byte 0
        .word 0                 ; end of program
