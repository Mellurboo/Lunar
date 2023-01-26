ASM=nasm
CC=gcc

SRCF=src
TOOLSF=tools
BLDF=build

.PHONY: all lunar_img kernel bootloader clean always tools_fat

all: lunar_img tools_fat

#
# Floppy image
#
lunar_img: $(BLDF)/lunar.img

$(BLDF)/lunar.img: bootloader kernel
	dd if=/dev/zero of=$(BLDF)/lunar.img bs=512 count=2880
	mkfs.fat -F 12 -n "NBOS" $(BLDF)/lunar.img
	dd if=$(BLDF)/bootloader.bin of=$(BLDF)/lunar.img conv=notrunc
	mcopy -i $(BLDF)/lunar.img $(BLDF)/kernel.bin "::kernel.bin"
	mcopy -i $(BLDF)/lunar.img test.txt "::test.txt"

#
# Bootloader
#
bootloader: $(BLDF)/bootloader.bin

$(BLDF)/bootloader.bin: always
	$(ASM) $(SRCF)/bootloader/boot.asm -f bin -o $(BLDF)/bootloader.bin

#
# Kernel
#
kernel: $(BLDF)/kernel.bin

$(BLDF)/kernel.bin: always
	$(ASM) $(SRCF)/kernel/kernel.asm -f bin -o $(BLDF)/kernel.bin

#
# Tools
#
tools_fat: $(BLDF)/tools/fat
$(BLDF)/tools/fat: always $(TOOLSF)/fat/fat.c
	mkdir -p $(BLDF)/tools
	$(CC) -g -o $(BLDF)/tools/fat $(TOOLSF)/fat/fat.c

#
# Always
#
always:
	mkdir -p $(BLDF)

#
# Clean
#
clean:
	rm -rf $(BLDF)/*
