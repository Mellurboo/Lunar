; this code is heavily inspired by nanobyes code, bootloaders are weird, i can make them but they're complicated
; and for the sake of it being open source so you dont have to see my spagetti ill add comments and stuff from his
; video, this is probably the worst part abt making an os, i cant wait to start working in C

org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

init:
    jmp main

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

main:
    ; >> Segments. ds & es -> ax 
    mov ax, 0   
    mov ds, ax
    mov es, ax

    ; >> Stack
    mov ss, ax
    mov sp, 0x7C00 ; the stack goes at the start of our os. so it cant overwrite stuff
    
    ;printing boot msg
    mov si, msg_booting
    call printscr

.halt:
    jmp .halt
;

msg_booting: db 'Lunar KRNL [OK]', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h