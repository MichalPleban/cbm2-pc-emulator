
%define VERSION_STRING		"0.73"
VERSION_NUMBER		equ		73


Version_Banner:
			db "PC Compatibility layer v", VERSION_STRING, " "
%ifdef ROM
			db "ROM "
%endif
			db "(C) 2017-2019 Micha", 9Ch, " Pleban", 10, 13, 0, '$'

Version_Output:
   			mov ax, Data_Segment
			mov es, ax
			push cs
			pop ds
			mov si, Version_Banner
			call Output_String
%ifdef SCREEN
            call Screen_ShowInfo
%endif
			ret

