; this code is heavily inspired by nanobyes code, bootloaders are weird, i can make them but they're complicated
; and for the sake of it being open source so you dont have to see my spagetti ill add comments and stuff from his
; video, this is probably the worst part abt making an os, i cant wait to start working in C

org 0x0
bits 16

%define ENDL 0x0D, 0x0A



init:
    MOV AH, 06h    ; Scroll up function
    XOR AL, AL     ; Clear entire screen
    XOR CX, CX     ; Upper left corner CH=row, CL=column
    MOV DX, 184FH  ; lower right corner DH=row, DL=column 
    MOV BH, 1Eh    ; YellowOnBlue
    INT 10H

    ;printing boot msg
    mov si, msg_booting
    call printscr


.halt:
    cli
    hlt 
;--
;Printing the boot string to the screen
printscr:
    push si
    push ax

.loop:
    lodsb      ;loads the next character to print
    or al, al   ;checks for the end of the string (!null?)
    jz .endstring

    mov ah, 0x0e    ;bios interrupt 
    mov bh, 0       ;were in text mode so we have to set the page number to 0
    int 0x10
    jmp .loop

.endstring:     ;we found the end of the string so lets pop regs
    pop si
    pop ax
    ret

; string printing done!
msg_booting: db 'Lunar KRNL [OK]', ENDL, 0