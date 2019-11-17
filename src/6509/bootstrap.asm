

CPU_ACCESS_BANK = $1


;--------------------------------------------------------------------
; Zeropage variables
;--------------------------------------------------------------------

file_id = $40
src_vector = $41
src_end = $43
dst_bank = $45
dst_vector = $46
file_ptr = $48

ipc_buffer = $0807


;--------------------------------------------------------------------
; Load address for the PRG file
;--------------------------------------------------------------------

.word $C000
.org $C000

        ; Fake data
        lda #$11
        sta ipc_buffer
        lda #$00
        sta ipc_buffer+1
        jmp BootstrapCopy


;--------------------------------------------------------------------
; Copy required files from bank 0
;--------------------------------------------------------------------

BootstrapCopy:
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
        brk
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
        
        sei
BootstrapLoad3:
        sty CPU_ACCESS_BANK     ; Copy one byte
        lda (src_vector),y
        ldx dst_bank
        stx CPU_ACCESS_BANK
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
        cli
        rts
        
BootstrapLoad9:
        sec
        rts

        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        