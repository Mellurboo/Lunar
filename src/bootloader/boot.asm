; this code is heavily inspired by nanobyes code, bootloaders are weird, i can make them but they're complicated
; and for the sake of it being open source so you dont have to see my spagetti ill add comments and stuff from his
; video, this is probably the worst part abt making an os, i cant wait to start working in C

org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;FAT 12 HEADERS
jmp short init
nop 

bdb_oem:                    db 'MSWIN4.1'
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_enteries_count:     dw 0E0h
bdb_total_sectors:          dw 2880         ;2880 * 512 = 1.44mb
bdb_media_descriptor_type   db 0F0h         ;F0 = 3.5" floppy
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
dbd_heads:                  dw 2
dbd_hidden_sectors:         dd 0
dbd_large_sector_count:     dd 0

; EBR

ebr_drive_number:           db 0            ;0x00 = Floppy, 0x80 = Hard disks
                            db 0            ;system reserved byte [0]
ebr_signature:              db 29h
ebr_volume_id:              db 10h, 10h, 10h, 10h   ; serial number
ebr_volume_label:           db 'LUNAROS    '    ;11 bytes
ebr_system_id:              db 'FAT12   '


init:
    

    ; >> Segments. ds & es -> ax 
    mov ax, 0   
    mov ds, ax
    mov es, ax

    ; >> Stack
    mov ss, ax
    mov sp, 0x7C00 ; the stack goes at the start of our os. so it cant overwrite stuff

    ; weird bioses patch
    push es
    push word .after
    retf


.after:
    ; read something to test ig
    mov [ebr_drive_number], dl

    ;printing boot msg
    mov si, msg_booting
    call printscr

    ;read drive params
    push es 
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F                    ;remove top 2 bits
    xor ch, ch 
    mov [bdb_sectors_per_track], cx

    inc dh
    mov [dbd_heads], dh

    ; read FAT root dir
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx
    add ax, [bdb_reserved_sectors]
    push ax

    ; calc the size of the root
    mov ax, [bdb_dir_enteries_count]
    shl ax, 5
    xor dx, dx
    div word [bdb_bytes_per_sector]

    test dx, dx
    jz .root_dir_after
    inc ax

.root_dir_after:

    mov cl, al 
    pop ax
    mov dl, [ebr_drive_number]
    mov bx, buffer
    call read_disk

    ; look for krnl
    xor bx, bx
    mov di, buffer

.findKrnl:
    mov si, kernel_file_bin
    mov cx, 11                  ;kernel file name length
    push di
    repe cmpsb
    pop di
    je .found_kernel

    add di, 32
    inc bx
    cmp bx, [bdb_dir_enteries_count]
    jl .findKrnl

    ; FATAL Kernel not found
    jmp .kernel_Missing

.found_kernel:
    ; di should have the addr to the entry structure
    mov ax, [di + 26]               ; 26 for offset
    mov [kernel_cluster], ax

    ; load FAT
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call read_disk

    ; read kernel
    mov bx, kernel_load_seg
    mov es, bx
    mov bx, kernel_load_offset

.load_kernel_loop:
    ; read next cluster
    mov ax, [kernel_cluster]

    ; FUTURE WARNING FOR ME : HARDCODED VALUE, THIS WILL ONLY WORK ON .IMG (floppy) DRIVES!
    add ax, 31
    mov cl, 1
    mov dl, [ebr_drive_number]
    call read_disk

    add bx, [bdb_bytes_per_sector]

    ; Calculate location of the next cluster
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx

    mov si, buffer
    add si, ax
    mov ax, [ds:si]

    or dx, dx
    jz .even 

.odd:
    shr ax, 4
    jmp .nxt_clus_after

.even:
    and ax, 0x0FFF

.nxt_clus_after:
    cmp ax, 0x0FF8
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.kernel_Missing:
    mov si, msg_missing_krnl
    call printscr
    jmp key_reboot

.read_finish:
;jumping to kernel begins here

    mov dl, [ebr_drive_number]

    mov ax, kernel_load_seg
    mov ds, ax
    mov es, ax

    jmp kernel_load_seg:kernel_load_offset

    jmp key_reboot          ; should never happen

    cli
    hlt


;--
;Printing the boot string to the screen
printscr:
    push si
    push ax
    push bx

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
    pop bx
    ret

; string printing done!

floppy_error:
    jmp key_reboot


key_reboot:
    mov si, msg_fatal_error
    call printscr

    mov ah, 0
    int 16h         ;wait for input (keypress)
    jmp 0FFFFh:0    ;back to the future baby (should reboot the PC)

.halt:
    cli             ;dissable interrupts
    hlt
;

; disk routine ps. whoever designed it like this, the physical shit, i hope you die. <3
lba_chs:

    ;save
    push ax
    push dx

    xor dx, dx                          ;0
    div word [bdb_sectors_per_track]    ;ax is then LBA / SectorsPerTrack
                                        ;dx is LBA % SectorsPerTrack
    
    inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                          ; cx = sector

    xor dx,dx                           ; dx = 0
    div word [dbd_heads]                ; ax = (LBA / SectorsPerTrack) / heads = cylinder
                                        ; dx = (LBA / SEctorsPerTrack) % Heads = head
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder
    shl ah, 6                           
    or cl, ah                           ; upper 2 bits of cylinder in cl

    ;restore
    pop ax
    mov dl, al
    pop ax
    ret

; Reading from the disk (sectors)

read_disk:
    push ax                 ;save registers we modify
    push bx
    push cx
    push dx
    push di

    push cx                 ;temporarily save the number of sectors to read
    call lba_chs            ;Calculate the CHS
    pop ax                  ;AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3               ;retry x times

.retry:
    pusha                   ;save all registers cause the bios likes to tickle things
    stc                     ;set the carry flag
    int 13h                 ;if cleared = true were good, if it hasnt thats not good
    jnc .done               ;jump if carry flag not set


    ;failure
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attemps used and the bootloader cannot read the drive
    jmp floppy_error

.done:
    popa

    pop ax                 ;load registers we modify
    pop bx
    pop cx
    pop dx
    pop di

    mov si, msg_readPass
    call printscr
    ret

;disk controller
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_booting:            db 'Lunar BOOT [OK]', ENDL, 0

msg_readPass:           db 'Lunar READ [OK]', ENDL, 0

msg_missing_krnl:       db 'KRNL ?', ENDL, 0
msg_fatal_error:        db 'Fatal err', ENDL, 0

; --- info

kernel_file_bin:        db "KERNEL  BIN"

kernel_cluster:         dw 0
kernel_load_seg         equ 0x2000
kernel_load_offset      equ 0

times 510-($-$$) db 0
dw 0AA55h

buffer:
