
Virtual_Segment equ MemTop - 20h

Virtual_Handle:
            push ax
            push ds
            push bp
            push sp
            pop bp
            mov ax, Virtual_Segment
            mov ds, ax
            in al, 0E5h
            mov [0000h], al
            mov ax, [ss:bp]
            mov [0002h], ax
            mov ax, [ss:bp+2]
            mov [0004h], ax
            mov ax, [ss:bp+4]
            mov [0006h], ax
            mov ax, [ss:bp+6]
            mov [0008h], ax
            mov ax, [ss:bp+8]
            mov [000Ah], ax
            mov ax, [ss:bp+10]
            mov [000Ch], ax
            pop bp
            pop ds
            pop ax
            iret

