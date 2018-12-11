SRCS_S := $(wildcard *.s)
SRCS_C := $(wildcard *.c)
SRCS := $(SRCS_S) $(SRCS_C)
PUREOBJS=$(subst .s,.o,$(SRCS_S)) $(subst .c,.o,$(SRCS_C))
OBJS := $(addprefix made/,$(PUREOBJS))

OUTSHS := $(addprefix made/,$(subst .s,.out.s.h,$(SRCS_S)))
INSHS := $(subst .out.,.in.,$(OUTSHS))

run: made/floppy.img
	qemu-system-x86_64 --nographic --enable-kvm -cpu host -m 8192 -drive file=hard.disk,format=raw -fda made/floppy.img
	
# Do the next two in different terminals:
step: made/floppy.img
	qemu-system-x86_64 -S -gdb tcp::9000 --nographic --enable-kvm -cpu host -m 8192 -drive file=hard.disk,format=raw -fda made/floppy.img

debug: made/kernel.o
	gdb -x script.gdb made/kernel.o

made/floppy.img: made/makeboot.exe made/bootsect.bin made/kernel.bin
	made/makeboot.exe made/floppy.img made/bootsect.bin made/kernel.bin

made:	
	mkdir made 2>/dev/null

made/makeboot.exe: makeboot.C Makefile made
	gcc -o made/makeboot.exe -x c makeboot.C -x none
	 
made/bootsect.bin: bootsect.asm
	nasm -f bin -o $@ $<

made/kernel.bin: made/kernel.o
	objcopy -R .note -R .comment -S -O binary $< $@

made/kernel.o: linker.lds $(OBJS)
	ld -nostartfiles -Ttext 0x8000 -Tlinker.lds -Map made/linked.map -o $@ $(OBJS)

made/%.o: %.c Makefile
	gcc -g -ffreestanding -fno-stack-protector -c -o $@ $<

made/%.o: %.s made/all.imports made/all.exports Makefile 
	nasm -f elf64 -F dwarf -g -o $@ $<

made/%.out.s.h:	%.s
	grep -h ';EXPORT' $< | sed 's/:.*$$/ ;$</ ; s/^/GLOBAL /' > $@

made/all.exports:	$(OUTSHS)
	cat $^ > $@

made/%.in.s.h:	%.s made/all.exports
	grep -v ';$<' made/all.exports | sed 's/GLOBAL/EXTERN/' > $@

made/all.imports:	$(INSHS)
	cat $^ > $@

clean:
	rm -rf made




