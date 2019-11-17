

CPU_ACCESS_BANK = $1


;--------------------------------------------------------------------
; Zeropage variables
;--------------------------------------------------------------------

file_id = $90
src_vector = $91
src_end = $93
dst_bank = $95
dst_vector = $96
file_ptr = $98

ipc_buffer = $0807


;--------------------------------------------------------------------
; KERNAL variables
;--------------------------------------------------------------------

QuoteSwitch = $d2
InsertFlag = $d3
WstFlag = $3fa


;--------------------------------------------------------------------
; KERNAL routines
;--------------------------------------------------------------------

RUNCOPRO = $ff72
CHKOUT = $ffc9
CLRCH = $ffcc
BSOUT = $ffd2


;--------------------------------------------------------------------
; Load address for the PRG file
;--------------------------------------------------------------------

.word $C000
.org $C000

        jsr BootstrapInit
        jmp RUNCOPRO

;--------------------------------------------------------------------
; Initialize 8088 and 6509 code vectors
;--------------------------------------------------------------------

BootstrapInit:
        ldy #$01
        sty CPU_ACCESS_BANK
        dey
        sty src_vector+1
        sty WstFlag
        sty WstFlag+1
        lda #$1C
        sta src_vector
BootstrapInit1:
        lda Bootstrap8088, y        ; Copy 8088 INT 07 and INT 08 vectors
        sta (src_vector), y
        iny
        cpy #8
        bne BootstrapInit1
        lda #$0F
        sta CPU_ACCESS_BANK
        
        lda #<BootstrapPrint        ; Address of IPC routine 12
        sta $0834
        lda #>BootstrapPrint
        sta $0835
        lda #$23
        sta $0922
        lda #<BootstrapCopy         ; Address of IPC routine 12
        sta $0854
        lda #>BootstrapCopy
        sta $0855
        lda #$0A
        sta $0932
        rts

Bootstrap8088:
        .word $FFF5, $F000
        .word $F1E2, $F000
    
;--------------------------------------------------------------------
; Copy required files from bank 0
;--------------------------------------------------------------------

BootstrapCopy:
        php
        sei
        ldx #0
        stx file_ptr
BootstrapCopy1:
        ldx file_ptr
        lda ipc_buffer,x
        sta file_id
        jsr BootstrapLoad
        lda file_id
        beq BootstrapCopy2
        inc file_ptr
        bne BootstrapCopy1
BootstrapCopy2:
        lda #$0F
        sta CPU_ACCESS_BANK
        plp
        rts

        
;--------------------------------------------------------------------
; Load one file from bank 0
; Input:
;       A = file ID
;--------------------------------------------------------------------

BootstrapLoad:
        ldy #$00
        sty src_vector+1
        sty CPU_ACCESS_BANK
        lda #$0A
        sta src_vector
BootstrapLoad1:
        lda (src_vector),y
        cmp file_id
        beq BootstrapLoad2      ; File is found, proceed to load
        cmp #$FF
        beq BootstrapLoad9      ; End of file chain, bail out
        ldy #$04
        lda (src_vector),y      ; Link to the next file
        tax
        iny
        lda (src_vector),y
        sta src_vector+1
        stx src_vector
        ldy #$00
        beq BootstrapLoad1      ; Loop, check next file in the chain

BootstrapLoad2:
        iny
        lda (src_vector),y      ; Load address of the file
        sta dst_bank
        iny
        lda (src_vector),y
        sta dst_vector
        iny
        lda (src_vector),y
        sta dst_vector+1
        iny
        lda (src_vector),y      ; Load end of the file
        sta src_end
        iny
        lda (src_vector),y
        sta src_end+1
        clc
        lda src_vector          ; Point the vector to the actual file data
        adc #$08
        sta src_vector
        lda src_vector+1
        adc #$00
        sta src_vector+1
        ldy #$00
        
BootstrapLoad3:
        lda #$00
        sta CPU_ACCESS_BANK     ; Copy one byte
        lda (src_vector),y
        tax
        lda dst_bank
        sta CPU_ACCESS_BANK
        txa
        sta (dst_vector),y
        inc src_vector          ; Move source pointer +1 byte
        bne BootstrapLoad3a
        inc src_vector+1
BootstrapLoad3a:
        inc dst_vector          ; Move destination pointer +1 byte
        bne BootstrapLoad3b
        inc dst_vector+1
BootstrapLoad3b:
        lda src_vector+1        ; Are we done yet?
        cmp src_end+1
        bne BootstrapLoad3
        lda src_vector
        cmp src_end
        bne BootstrapLoad3
        clc
        rts
        
BootstrapLoad9:
        sec
        rts

;--------------------------------------------------------------------
; Character output routine
;--------------------------------------------------------------------

BootstrapPrint:
        ldx #$03
        jsr CHKOUT
        lda ipc_buffer
        jsr BSOUT
        lda #$00
        sta QuoteSwitch
        sta InsertFlag
        jsr CLRCH
        rts
        
        