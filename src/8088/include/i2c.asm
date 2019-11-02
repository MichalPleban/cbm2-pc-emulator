

; -----------------------------------------------------------------
; Send I2C start condition
; -----------------------------------------------------------------

I2C_Start:
            in al, 0E2h
            or al, 01h
            out 0E2h, al
            call I2C_Delay
            or al, 02h
            out 0E2h, al
            call I2C_Delay
            and al, 0FEh
            out 0E2H, al
            call I2C_Delay
            and al, 0FDh
            out 0E2h, al
            call I2C_Delay
            ret

; -----------------------------------------------------------------
; Send I2C stop condition
; -----------------------------------------------------------------

I2C_Stop:
            in al, 0E2h
            and al, 0FEh
            out 0E2h, al
            call I2C_Delay
            or al, 02h
            out 0E2h, al
            call I2C_Delay
            or al, 01h
            out 0E2h, al
            call I2C_Delay
            ret

; -----------------------------------------------------------------
; Send I2C byte
; Input:
;       AL - byte to send
; Output:
;       C flag set if there was no acknowledge
; -----------------------------------------------------------------

I2C_Send:
        push cx
        mov cx, 8
        mov ah, al
        in al, 0E2h
I2C_Send1:
        and al, 0FCh
        rcl ah, 1
        adc al, 0
        out 0E2h, al
        nop
        nop
        or al, 02h
        out 0E2h, al
        and al, 0FDh
        call I2C_Delay
        out 0E2h, al
        loop I2C_Send1
        call I2C_Delay
        or al, 03h
        out 0E2h, al
        call I2C_Delay
        in al, 0E2h
        mov ah, al
        and al, 0FDh
        out 0E2h, al
        pop cx
        rcr ah, 1
        ret

; -----------------------------------------------------------------
; Receive I2C byte
; Input:
;       C flag set if no acknowledge has to be sent
; Output:
;       AL - received byte
; -----------------------------------------------------------------

I2C_Receive:
        push cx
        pushf
        xor ah, ah
        in al, 0E2h
        or al, 01h
        out 0E2h, al
        mov cx, 8
I2C_Receive1:
        call I2C_Delay
        or al, 03h
        out 0E2h, al
I2C_Receive2:
        in al, 0E2h
        test al, 02h
        jz I2C_Receive2
        in al, 0E2h
        rcr al, 1
        rcl ah, 1
        in al, 0E2h
        and al, 0FDh
        out 0E2h, al
        loop I2C_Receive1
        and al, 0FEh
        popf
        adc al, 00
        out 0E2h, al
        call I2C_Delay
        or al, 02h
        out 0E2h, al
        call I2C_Delay
        and al, 0FDh
        out 0E2h, al
        or al, 01h
        out 0E2h, al
        mov al, ah
        pop cx
        ret

; -----------------------------------------------------------------
; I2C delay loop calibrated for 100 kHz
; -----------------------------------------------------------------

I2C_Delay:
        nop
        nop
        nop
        nop
        nop
        ret

