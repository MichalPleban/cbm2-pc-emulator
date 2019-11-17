
[CPU 8086]

%include 'src/8088/payload.asm'

    		times 0F000h-($-$$) db 0FFh

RomStart:
    	
%include 'src/8088/rom/ipc.asm'
%include 'src/8088/rom/bootstrap.asm'

RomEnd:
    	
    		times 0FFF0h-($-$$) db 0FFh	
    
    		jmp	0F000h:startf
    		jmp	0F000h:Bootstrap
    
    		times 0FFFAh-($-$$) db 0FFh
    		
    		dw "PC"
    		dw 80
    		
    		dw 0FFFFh
