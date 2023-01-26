ASM=nasm
SRCF=src
BLDF=builds

.PHONY: all lunar_img kernel bootloader clean always

#floppy
lunar_img: $(BLDF)/lunar.img

$(BLDF)/lunar.img: bootloader kernel
	dd if=/dev/zero of=$(BLDF)/lunar.img bs=512 count=2880
	mkfs.fat -F 12 -n "LUNR" $(BLDF)/lunar.img
	dd if=$(BLDF)/boot.bin of=$(BLDF)/lunar.img conv=notrunc
	mcopy -i $(BLDF)/lunar.img $(BLDF)/kernel.bin "::kernel.bin"

#BootLoader
bootloader: $(BLDF)/boot.bin

$(BLDF)/boot.bin: always
	$(ASM) $(SRCF)/bootloader/boot.asm -f bin -o $(BLDF)/boot.bin


#KernelCompile
kernel: $(BLDF)/kernel.bin

$(BLDF)/kernel.bin: always
	$(ASM) $(SRCF)/kernel/kernel.asm -f bin -o $(BLDF)/kernel.bin

#Always

always:
	mkdir -p $(BLDF)

clean:
	rm -rf $(BLDF)/*